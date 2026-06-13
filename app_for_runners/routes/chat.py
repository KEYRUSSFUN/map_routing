import os

from flask import Blueprint, request, jsonify, send_file
from extensions import db, socketio
from models import User, GroupChat, GroupMessage, UserGroupChatAssociation, ChatRouteShare
from utils.auth import token_required
from utils.route_share_storage import (
    delete_route_share_file,
    route_share_file_path,
    save_chat_route_file,
)
from utils.message_reactions import (
    ALLOWED_REACTION_EMOJIS,
    serialize_message_reactions,
    toggle_message_reaction,
)
from sqlalchemy.exc import IntegrityError
from datetime import datetime, timezone

chat_bp = Blueprint('chat', __name__)


def _utcnow():
    return datetime.now(timezone.utc)


def _member_name(user):
    if user.user_info:
        return user.user_info.name
    return f'User {user.id_User}'


def _serialize_route_share(route_share):
    if not route_share:
        return None
    return {
        'id': route_share.id,
        'originalFilename': route_share.original_filename,
        'title': route_share.title or route_share.original_filename,
        'fileSize': route_share.file_size,
    }


def _serialize_message(message):
    sender_name = (
        _member_name(message.sender) if message.sender else f'User {message.sender_id}'
    )
    data = {
        'id': message.id,
        'sender_id': message.sender_id,
        'sender': sender_name,
        'content': message.content,
        'message_type': message.message_type or 'text',
        'timestamp': message.timestamp.isoformat(),
    }
    if message.message_type == 'route' and message.route_share:
        data['route_share'] = _serialize_route_share(message.route_share)
    data['reactions'] = serialize_message_reactions(message)
    return data


def _message_preview(message):
    if not message:
        return ''
    if message.message_type == 'route' and message.route_share:
        title = message.route_share.title or message.route_share.original_filename
        return f'Маршрут: {title}'
    return message.content


def _chat_member_or_403(user_id, chat_id):
    chat = GroupChat.query.get(chat_id)
    if not chat:
        return None, None, (jsonify({'error': 'Chat not found'}), 404)

    association = UserGroupChatAssociation.query.filter_by(
        user_id=user_id, chat_id=chat_id
    ).first()
    if not association:
        return None, None, (jsonify({'error': 'Access denied'}), 403)

    return chat, association, None


def _emit_chat_message(chat_id, message_data):
    socketio.emit('new_message', message_data, room=str(chat_id))


def _emit_message_deleted(chat_id, message_id):
    socketio.emit(
        'message_deleted',
        {'chat_id': chat_id, 'message_id': message_id},
        room=str(chat_id),
    )


def _emit_reactions_updated(chat_id, message_id, reactions):
    socketio.emit(
        'reactions_updated',
        {
            'chat_id': chat_id,
            'message_id': message_id,
            'reactions': reactions,
        },
        room=str(chat_id),
    )


def _delete_message_route_share(message):
    route_share = message.route_share
    if not route_share:
        return
    delete_route_share_file(route_share.stored_filename)
    db.session.delete(route_share)


def _last_message_sender_name(message):
    if not message:
        return ''
    if message.sender and message.sender.user_info:
        return message.sender.user_info.name
    return f'User {message.sender_id}'


def _resolve_creator_id(chat):
    if chat.creator_id is not None:
        return chat.creator_id

    earliest = (
        UserGroupChatAssociation.query
        .filter_by(chat_id=chat.id)
        .order_by(UserGroupChatAssociation.joined_at.asc())
        .first()
    )
    if earliest:
        return earliest.user_id

    members = list(chat.members)
    if members:
        return members[0].id_User
    return None


def _creator_name(chat):
    creator_id = _resolve_creator_id(chat)
    if creator_id is None:
        return None
    creator = User.query.get(creator_id)
    if not creator:
        return None
    return _member_name(creator)


def _serialize_participants(chat):
    creator_id = _resolve_creator_id(chat)
    participants = []
    for member in chat.members:
        participants.append({
            'id': member.id_User,
            'name': _member_name(member),
            'isCreator': creator_id is not None and creator_id == member.id_User,
        })
    participants.sort(key=lambda item: (not item['isCreator'], item['name'].lower()))
    return participants


def _unread_count(association, chat, user_id):
    last_read = association.last_read_at or association.joined_at
    if last_read is None:
        last_read = datetime.min.replace(tzinfo=timezone.utc)

    query = chat.messages.filter(
        GroupMessage.timestamp > last_read,
        GroupMessage.sender_id != user_id,
    )
    return query.count()


def _mark_chat_read(user_id, chat_id):
    association = UserGroupChatAssociation.query.filter_by(
        user_id=user_id, chat_id=chat_id
    ).first()
    if not association:
        return False

    association.last_read_at = _utcnow()
    db.session.commit()
    return True


def _is_chat_creator(chat, user_id):
    creator_id = _resolve_creator_id(chat)
    return creator_id is not None and creator_id == user_id


def _is_invitation_unread(association, chat, user_id):
    if not association or association.invitation_seen_at is not None:
        return False
    creator_id = _resolve_creator_id(chat)
    return creator_id is not None and creator_id != user_id


def _add_chat_member(chat_id, member_id, *, invitation_seen=False):
    now = _utcnow()
    db.session.add(UserGroupChatAssociation(
        user_id=member_id,
        chat_id=chat_id,
        invitation_seen_at=now if invitation_seen else None,
    ))


@chat_bp.route('/api/group_chats', methods=['GET'])
@token_required
def get_group_chats(user_id):
    user = User.query.get(user_id)
    if not user:
        return jsonify({'error': 'User not found'}), 404

    chat_data = []
    unread_invitation_count = 0
    for chat in user.group_chats:
        association = UserGroupChatAssociation.query.filter_by(
            user_id=user_id, chat_id=chat.id
        ).first()
        last_message = chat.messages.order_by(GroupMessage.timestamp.desc()).first()
        unread_count = _unread_count(association, chat, user_id) if association else 0
        is_invitation_unread = _is_invitation_unread(association, chat, user_id)
        if is_invitation_unread:
            unread_invitation_count += 1
        chat_data.append({
            'id': chat.id,
            'title': chat.title,
            'lastMessage': _message_preview(last_message),
            'lastMessageSender': _last_message_sender_name(last_message),
            'unreadCount': unread_count,
            'creatorId': _resolve_creator_id(chat),
            'creatorName': _creator_name(chat),
            'isInvitationUnread': is_invitation_unread,
        })

    return jsonify({
        'chats': chat_data,
        'unreadInvitationCount': unread_invitation_count,
    }), 200


@chat_bp.route('/api/group_chats', methods=['POST'])
@token_required
def create_group_chat(user_id):
    data = request.get_json()
    title = data.get('title')
    member_ids = data.get('members', [])

    if not title:
        return jsonify({'error': 'Название чата обязательно'}), 400

    new_chat = GroupChat(title=title, creator_id=user_id)
    db.session.add(new_chat)
    db.session.flush()

    all_member_ids = set(member_ids)
    all_member_ids.add(user_id)

    try:
        for member_id in all_member_ids:
            if User.query.get(member_id):
                existing_association = UserGroupChatAssociation.query.filter_by(
                    user_id=member_id, chat_id=new_chat.id
                ).first()
                if not existing_association:
                    _add_chat_member(
                        new_chat.id,
                        member_id,
                        invitation_seen=member_id == user_id,
                    )

        db.session.commit()
        return jsonify({
            'id': new_chat.id,
            'title': new_chat.title,
            'lastMessage': '',
            'lastMessageSender': '',
            'unreadCount': 0,
            'creatorId': new_chat.creator_id,
        }), 201
    except IntegrityError:
        db.session.rollback()
        return jsonify({'error': 'Чат с такими участниками уже существует или произошёл конфликт.'}), 409
    except Exception:
        db.session.rollback()
        return jsonify({'error': 'Ошибка при создании чата'}), 500


@chat_bp.route('/api/group_chats/<int:chat_id>/join', methods=['POST'])
@token_required
def join_group_chat(user_id, chat_id):
    chat = GroupChat.query.get(chat_id)
    if not chat:
        return jsonify({'error': 'Chat not found'}), 404

    association = UserGroupChatAssociation.query.filter_by(user_id=user_id, chat_id=chat_id).first()
    if association:
        return jsonify({'message': 'Already a member'}), 200

    _add_chat_member(chat_id, user_id, invitation_seen=True)
    db.session.commit()

    return jsonify({'message': 'Joined chat successfully'}), 201


@chat_bp.route('/api/group_chats/<int:chat_id>/add_user', methods=['POST'])
@token_required
def add_user_to_chat(user_id, chat_id):
    data = request.get_json()
    new_user_id = data.get('user_id')

    if not new_user_id:
        return jsonify({'error': 'Не указан ID пользователя'}), 400

    chat = GroupChat.query.get(chat_id)
    if not chat:
        return jsonify({'error': 'Чат не найден'}), 404

    if not User.query.get(new_user_id):
        return jsonify({'error': 'Пользователь не найден'}), 404

    existing = UserGroupChatAssociation.query.filter_by(user_id=new_user_id, chat_id=chat_id).first()
    if existing:
        return jsonify({'message': 'Пользователь уже в чате'}), 200

    _add_chat_member(chat_id, new_user_id, invitation_seen=False)
    db.session.commit()
    return jsonify({'message': 'Пользователь добавлен в чат'}), 201


@chat_bp.route('/api/group_chats/<int:chat_id>', methods=['GET'])
@token_required
def get_group_chat_details(user_id, chat_id):
    chat = GroupChat.query.get(chat_id)
    if not chat:
        return jsonify({'error': 'Chat not found'}), 404

    assoc = UserGroupChatAssociation.query.filter_by(user_id=user_id, chat_id=chat_id).first()
    if not assoc:
        return jsonify({'error': 'Access denied'}), 403

    messages = [
        _serialize_message(msg)
        for msg in chat.messages.order_by(GroupMessage.timestamp.asc()).all()
    ]

    creator_id = _resolve_creator_id(chat)

    return jsonify({
        'id': chat.id,
        'title': chat.title,
        'creatorId': creator_id,
        'creatorName': _creator_name(chat),
        'participants': _serialize_participants(chat),
        'messages': messages
    }), 200


@chat_bp.route('/api/group_chats/<int:chat_id>', methods=['DELETE'])
@token_required
def delete_group_chat(user_id, chat_id):
    chat = GroupChat.query.get(chat_id)
    if not chat:
        return jsonify({'error': 'Chat not found'}), 404

    if not _is_chat_creator(chat, user_id):
        return jsonify({'error': 'Only the creator can delete this chat'}), 403

    route_shares = ChatRouteShare.query.filter_by(chat_id=chat_id).all()
    for route_share in route_shares:
        delete_route_share_file(route_share.stored_filename)

    ChatRouteShare.query.filter_by(chat_id=chat_id).delete()
    GroupMessage.query.filter_by(chat_id=chat_id).delete()
    UserGroupChatAssociation.query.filter_by(chat_id=chat_id).delete()
    db.session.delete(chat)
    db.session.commit()

    return jsonify({'message': 'Chat deleted'}), 200


@chat_bp.route('/api/group_chats/<int:chat_id>/members/<int:member_id>', methods=['DELETE'])
@token_required
def remove_chat_member(user_id, chat_id, member_id):
    chat = GroupChat.query.get(chat_id)
    if not chat:
        return jsonify({'error': 'Chat not found'}), 404

    if not _is_chat_creator(chat, user_id):
        return jsonify({'error': 'Only the creator can remove members'}), 403

    if member_id == _resolve_creator_id(chat):
        return jsonify({'error': 'Creator cannot be removed. Delete the chat instead.'}), 400

    association = UserGroupChatAssociation.query.filter_by(
        user_id=member_id, chat_id=chat_id
    ).first()
    if not association:
        return jsonify({'error': 'Member not found in chat'}), 404

    db.session.delete(association)
    db.session.commit()

    return jsonify({'message': 'Member removed'}), 200


@chat_bp.route('/api/group_chats/<int:chat_id>/read', methods=['POST'])
@token_required
def mark_group_chat_read(user_id, chat_id):
    chat = GroupChat.query.get(chat_id)
    if not chat:
        return jsonify({'error': 'Chat not found'}), 404

    association = UserGroupChatAssociation.query.filter_by(
        user_id=user_id, chat_id=chat_id
    ).first()
    if not association:
        return jsonify({'error': 'Access denied'}), 403

    now = _utcnow()
    association.last_read_at = now
    association.invitation_seen_at = now
    db.session.commit()

    return jsonify({
        'message': 'Chat marked as read',
        'unreadCount': 0,
    }), 200


@chat_bp.route('/api/group_chats/invitations/mark_seen', methods=['POST'])
@token_required
def mark_group_invitations_seen(user_id):
    associations = UserGroupChatAssociation.query.filter_by(user_id=user_id).all()
    now = _utcnow()
    updated = 0

    for association in associations:
        chat = GroupChat.query.get(association.chat_id)
        if not chat:
            continue
        if _is_invitation_unread(association, chat, user_id):
            association.invitation_seen_at = now
            updated += 1

    db.session.commit()

    return jsonify({
        'message': 'Group invitations marked as seen',
        'unreadInvitationCount': 0,
        'updated': updated,
    }), 200


@chat_bp.route('/api/group_chats/<int:chat_id>/route_shares', methods=['POST'])
@token_required
def share_route_in_chat(user_id, chat_id):
    chat, _, error = _chat_member_or_403(user_id, chat_id)
    if error:
        return error

    file_storage = request.files.get('gpx')
    title = (request.form.get('title') or '').strip() or None

    try:
        original_filename, stored_filename, file_size = save_chat_route_file(file_storage)
    except ValueError as exc:
        return jsonify({'error': str(exc)}), 400

    route_share = ChatRouteShare(
        chat_id=chat_id,
        uploader_id=user_id,
        original_filename=original_filename,
        stored_filename=stored_filename,
        title=title or original_filename,
        file_size=file_size,
    )
    db.session.add(route_share)
    db.session.flush()

    preview = f'Маршрут: {route_share.title}'
    message = GroupMessage(
        chat_id=chat_id,
        sender_id=user_id,
        content=preview,
        message_type='route',
        route_share_id=route_share.id,
    )
    db.session.add(message)
    db.session.commit()

    message_data = _serialize_message(message)
    _emit_chat_message(chat_id, message_data)

    return jsonify({'message': message_data}), 201


@chat_bp.route(
    '/api/group_chats/<int:chat_id>/route_shares/<int:share_id>/download',
    methods=['GET'],
)
@token_required
def download_shared_route(user_id, chat_id, share_id):
    _, _, error = _chat_member_or_403(user_id, chat_id)
    if error:
        return error

    route_share = ChatRouteShare.query.filter_by(
        id=share_id, chat_id=chat_id
    ).first()
    if not route_share:
        return jsonify({'error': 'Route not found'}), 404

    file_path = route_share_file_path(route_share.stored_filename)
    if not file_path or not os.path.isfile(file_path):
        return jsonify({'error': 'Route file is missing on server'}), 404

    return send_file(
        file_path,
        mimetype='application/gpx+xml',
        as_attachment=True,
        download_name=route_share.original_filename,
    )


@chat_bp.route(
    '/api/group_chats/<int:chat_id>/messages/<int:message_id>',
    methods=['DELETE'],
)
@token_required
def delete_group_message(user_id, chat_id, message_id):
    _, _, error = _chat_member_or_403(user_id, chat_id)
    if error:
        return error

    message = GroupMessage.query.filter_by(
        id=message_id, chat_id=chat_id
    ).first()
    if not message:
        return jsonify({'error': 'Message not found'}), 404

    if message.sender_id != user_id:
        return jsonify({'error': 'You can only delete your own messages'}), 403

    _delete_message_route_share(message)
    db.session.delete(message)
    db.session.commit()

    _emit_message_deleted(chat_id, message_id)

    return jsonify({'message': 'Message deleted', 'message_id': message_id}), 200


@chat_bp.route(
    '/api/group_chats/<int:chat_id>/messages/<int:message_id>/reactions',
    methods=['POST'],
)
@token_required
def toggle_group_message_reaction(user_id, chat_id, message_id):
    _, _, error = _chat_member_or_403(user_id, chat_id)
    if error:
        return error

    message = GroupMessage.query.filter_by(
        id=message_id, chat_id=chat_id
    ).first()
    if not message:
        return jsonify({'error': 'Message not found'}), 404

    data = request.get_json() or {}
    emoji = (data.get('emoji') or '').strip()
    if emoji not in ALLOWED_REACTION_EMOJIS:
        return jsonify({'error': 'Invalid reaction emoji'}), 400

    try:
        reactions = toggle_message_reaction(message_id, user_id, emoji)
    except ValueError as exc:
        return jsonify({'error': str(exc)}), 400

    _emit_reactions_updated(chat_id, message_id, reactions)

    return jsonify({
        'message_id': message_id,
        'reactions': reactions,
    }), 200
