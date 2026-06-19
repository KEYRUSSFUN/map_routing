import json
import os

from flask import Blueprint, current_app, request, jsonify, send_file, url_for
from extensions import db, socketio
from models import User, GroupChat, GroupMessage, UserGroupChatAssociation, ChatRouteShare, MessageReaction
from utils.auth import token_required
from utils.route_share_photo_storage import (
    delete_route_share_photo,
    route_share_photo_path,
    save_route_share_photo,
)
from utils.route_share_storage import (
    delete_route_share_file,
    route_share_file_path,
    save_chat_route_file,
)
from utils.chat_photo_storage import (
    chat_photo_file_path,
    delete_chat_photo,
    save_chat_photo,
)
from utils.message_reactions import (
    ALLOWED_REACTION_EMOJIS,
    reactions_map_for_message_ids,
    serialize_message_reactions,
    toggle_message_reaction,
)
from utils.user_avatar import avatar_url_for
from sqlalchemy.exc import IntegrityError
from sqlalchemy import and_, func, or_, select, update
from sqlalchemy.orm import joinedload
from datetime import datetime, timezone
from utils.datetime_utils import utc_isoformat

chat_bp = Blueprint('chat', __name__)


def _utcnow():
    return datetime.now(timezone.utc)


def _member_name(user):
    if user.user_info:
        return user.user_info.name
    return f'User {user.id_User}'


def _avatar_url_for_user(user):
    if not user or not user.user_info:
        return None
    return avatar_url_for(user.user_info, external=False)


def _parse_tags(raw):
    if raw is None:
        return []
    if isinstance(raw, list):
        return [str(item).strip() for item in raw if str(item).strip()]
    if isinstance(raw, str):
        text = raw.strip()
        if not text:
            return []
        try:
            parsed = json.loads(text)
            if isinstance(parsed, list):
                return [str(item).strip() for item in parsed if str(item).strip()]
        except json.JSONDecodeError:
            return [part.strip() for part in text.split(',') if part.strip()]
    return []


def _route_share_photo_url(route_share):
    if not route_share or not route_share.photo_filename:
        return None
    return url_for(
        'chat.download_route_share_photo',
        chat_id=route_share.chat_id,
        share_id=route_share.id,
    )


def _serialize_route_share(route_share):
    if not route_share:
        return None
    snapshot = None
    if route_share.snapshot_json:
        try:
            snapshot = json.loads(route_share.snapshot_json)
        except json.JSONDecodeError:
            snapshot = None
    data = {
        'id': route_share.id,
        'originalFilename': route_share.original_filename,
        'title': route_share.title or route_share.original_filename,
        'fileSize': route_share.file_size,
        'hasPhoto': bool(route_share.photo_filename),
    }
    if snapshot is not None:
        data['snapshot'] = snapshot
    photo_url = _route_share_photo_url(route_share)
    if photo_url:
        data['photoUrl'] = photo_url
    return data


def _serialize_message(message, reactions=None):
    sender_name = (
        _member_name(message.sender) if message.sender else f'User {message.sender_id}'
    )
    data = {
        'id': message.id,
        'sender_id': message.sender_id,
        'sender': sender_name,
        'sender_avatar_url': _avatar_url_for_user(message.sender),
        'content': message.content,
        'message_type': message.message_type or 'text',
        'timestamp': utc_isoformat(message.timestamp),
    }
    if message.message_type == 'route' and message.route_share:
        data['route_share'] = _serialize_route_share(message.route_share)
    if reactions is None:
        data['reactions'] = serialize_message_reactions(message)
    else:
        data['reactions'] = reactions
    return data


def _load_chat_messages(chat, after_id=None):
    query = chat.messages.order_by(GroupMessage.timestamp.asc())
    if after_id is not None:
        query = query.filter(GroupMessage.id > after_id)
    return query.options(
        joinedload(GroupMessage.sender).joinedload(User.user_info),
        joinedload(GroupMessage.route_share),
    ).all()


def _serialize_messages(messages):
    reactions_map = reactions_map_for_message_ids([message.id for message in messages])
    return [
        _serialize_message(
            message,
            reactions=reactions_map.get(message.id, []),
        )
        for message in messages
    ]


def _latest_messages_by_chat(chat_ids):
    if not chat_ids:
        return {}

    subq = (
        db.session.query(
            GroupMessage.chat_id,
            func.max(GroupMessage.timestamp).label('max_ts'),
        )
        .filter(GroupMessage.chat_id.in_(chat_ids))
        .group_by(GroupMessage.chat_id)
        .subquery()
    )
    messages = (
        db.session.query(GroupMessage)
        .join(
            subq,
            and_(
                GroupMessage.chat_id == subq.c.chat_id,
                GroupMessage.timestamp == subq.c.max_ts,
            ),
        )
        .options(
            joinedload(GroupMessage.sender).joinedload(User.user_info),
            joinedload(GroupMessage.route_share),
        )
        .all()
    )
    latest = {}
    for message in messages:
        existing = latest.get(message.chat_id)
        if existing is None or message.id > existing.id:
            latest[message.chat_id] = message
    return latest


def _unread_counts_by_chat(user_id, associations_by_chat):
    if not associations_by_chat:
        return {}

    conditions = []
    for chat_id, association in associations_by_chat.items():
        last_read = association.last_read_at or association.joined_at
        if last_read is None:
            last_read = datetime.min.replace(tzinfo=timezone.utc)
        conditions.append(
            and_(
                GroupMessage.chat_id == chat_id,
                GroupMessage.timestamp > last_read,
                GroupMessage.sender_id != user_id,
            )
        )

    rows = (
        db.session.query(GroupMessage.chat_id, func.count(GroupMessage.id))
        .filter(or_(*conditions))
        .group_by(GroupMessage.chat_id)
        .all()
    )
    return {chat_id: count for chat_id, count in rows}


def _creator_names_by_id(creator_ids):
    if not creator_ids:
        return {}
    users = (
        User.query.filter(User.id_User.in_(creator_ids))
        .options(joinedload(User.user_info))
        .all()
    )
    return {user.id_User: _member_name(user) for user in users}


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
    payload = {**message_data, 'chat_id': chat_id}
    socketio.emit('new_message', payload, room=str(chat_id))


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


def _emit_chat_deleted(chat_id, member_user_ids):
    payload = {'chat_id': chat_id}
    socketio.emit('chat_deleted', payload, room=str(chat_id))
    for member_id in member_user_ids:
        socketio.emit('chat_deleted', payload, room=_user_room(member_id))


def _chat_photo_url(chat):
    if not chat or not chat.avatar_filename:
        return None
    path = chat_photo_file_path(chat)
    base = url_for('chat.get_group_chat_photo', chat_id=chat.id)
    if path and os.path.isfile(path):
        version = int(os.path.getmtime(path))
        return f'{base}?v={version}'
    return base


def _association_notifications_muted(association):
    if association is None:
        return False
    return bool(association.notifications_muted)


def _serialize_chat_summary(chat, user_id, association=None):
    if association is None:
        association = UserGroupChatAssociation.query.filter_by(
            user_id=user_id, chat_id=chat.id
        ).first()
    creator_id = chat.creator_id or _resolve_creator_id(chat)
    creator_names = _creator_names_by_id({creator_id}) if creator_id else {}
    return {
        'id': chat.id,
        'title': chat.title,
        'lastMessage': '',
        'lastMessageSender': '',
        'unreadCount': 0,
        'creatorId': creator_id,
        'creatorName': creator_names.get(creator_id) if creator_id else None,
        'isInvitationUnread': _is_invitation_unread(association, chat, user_id),
        'photoUrl': _chat_photo_url(chat),
        'notificationsMuted': _association_notifications_muted(association),
    }


def _emit_chat_updated(chat):
    member_ids = db.session.scalars(
        select(UserGroupChatAssociation.user_id).where(
            UserGroupChatAssociation.chat_id == chat.id
        )
    ).all()
    for member_id in member_ids:
        association = UserGroupChatAssociation.query.filter_by(
            user_id=member_id, chat_id=chat.id
        ).first()
        payload = {
            'chat': _serialize_chat_summary(chat, member_id, association),
        }
        socketio.emit('chat_updated', payload, room=_user_room(member_id))


def _normalize_member_id(raw):
    if raw is None:
        return None
    try:
        return int(raw)
    except (TypeError, ValueError):
        return None


def _normalize_member_ids(raw_ids, creator_id):
    ids = set()
    creator = _normalize_member_id(creator_id)
    if creator is not None:
        ids.add(creator)
    if isinstance(raw_ids, list):
        for raw in raw_ids:
            normalized = _normalize_member_id(raw)
            if normalized is not None:
                ids.add(normalized)
    return ids


def _emit_chat_added(chat, recipient_user_ids):
    for member_id in recipient_user_ids:
        association = UserGroupChatAssociation.query.filter_by(
            user_id=member_id, chat_id=chat.id
        ).first()
        payload = {
            'chat': _serialize_chat_summary(chat, member_id, association),
        }
        socketio.emit('chat_added', payload, room=_user_room(member_id))


def _user_room(user_id):
    return f'user_{user_id}'


def _delete_message_route_share(message):
    route_share = message.route_share
    if not route_share:
        return
    delete_route_share_file(route_share.stored_filename)
    if route_share.photo_filename:
        delete_route_share_photo(route_share.photo_filename)
    message.route_share_id = None
    db.session.flush()
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
            'avatar_url': _avatar_url_for_user(member),
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
    user = User.query.options(joinedload(User.group_chats)).get(user_id)
    if not user:
        return jsonify({'error': 'User not found'}), 404

    chats = list(user.group_chats)
    if not chats:
        return jsonify({'chats': [], 'unreadInvitationCount': 0}), 200

    chat_ids = [chat.id for chat in chats]
    associations = {
        row.chat_id: row
        for row in UserGroupChatAssociation.query.filter(
            UserGroupChatAssociation.user_id == user_id,
            UserGroupChatAssociation.chat_id.in_(chat_ids),
        ).all()
    }
    latest_by_chat = _latest_messages_by_chat(chat_ids)
    unread_by_chat = _unread_counts_by_chat(user_id, associations)
    creator_names = _creator_names_by_id(
        {chat.creator_id for chat in chats if chat.creator_id},
    )

    chat_data = []
    unread_invitation_count = 0
    for chat in chats:
        association = associations.get(chat.id)
        last_message = latest_by_chat.get(chat.id)
        unread_count = unread_by_chat.get(chat.id, 0) if association else 0
        is_invitation_unread = _is_invitation_unread(association, chat, user_id)
        if is_invitation_unread:
            unread_invitation_count += 1

        creator_id = chat.creator_id or _resolve_creator_id(chat)
        chat_data.append({
            'id': chat.id,
            'title': chat.title,
            'lastMessage': _message_preview(last_message),
            'lastMessageSender': _last_message_sender_name(last_message),
            'unreadCount': unread_count,
            'creatorId': creator_id,
            'creatorName': creator_names.get(creator_id) if creator_id else None,
            'isInvitationUnread': is_invitation_unread,
            'photoUrl': _chat_photo_url(chat),
            'notificationsMuted': _association_notifications_muted(association),
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

    all_member_ids = _normalize_member_ids(member_ids, user_id)

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
        invited_ids = [mid for mid in all_member_ids if mid != user_id]
        _emit_chat_added(new_chat, invited_ids)
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
    _emit_chat_added(chat, [new_user_id])
    return jsonify({'message': 'Пользователь добавлен в чат'}), 201


@chat_bp.route('/api/group_chats/<int:chat_id>', methods=['GET'])
@token_required
def get_group_chat_details(user_id, chat_id):
    chat, association, error = _chat_member_or_403(user_id, chat_id)
    if error:
        return error

    chat = GroupChat.query.options(
        joinedload(GroupChat.members).joinedload(User.user_info),
    ).get(chat_id)

    include_messages = request.args.get('include_messages', 'true').lower() != 'false'
    messages = _serialize_messages(_load_chat_messages(chat)) if include_messages else []

    creator_id = _resolve_creator_id(chat)

    return jsonify({
        'id': chat.id,
        'title': chat.title,
        'creatorId': creator_id,
        'creatorName': _creator_name(chat),
        'participants': _serialize_participants(chat),
        'messages': messages,
        'photoUrl': _chat_photo_url(chat),
        'notificationsMuted': _association_notifications_muted(association),
    }), 200


@chat_bp.route('/api/group_chats/<int:chat_id>', methods=['PATCH'])
@token_required
def update_group_chat(user_id, chat_id):
    chat, _, error = _chat_member_or_403(user_id, chat_id)
    if error:
        return error

    if not _is_chat_creator(chat, user_id):
        return jsonify({'error': 'Only the creator can edit this chat'}), 403

    data = request.get_json() or {}
    title = (data.get('title') or '').strip()
    if not title:
        return jsonify({'error': 'Название чата обязательно'}), 400

    chat.title = title
    db.session.commit()
    _emit_chat_updated(chat)

    return jsonify({
        'success': True,
        'title': chat.title,
        'photoUrl': _chat_photo_url(chat),
    }), 200


@chat_bp.route('/api/group_chats/<int:chat_id>/settings', methods=['PATCH'])
@token_required
def update_group_chat_settings(user_id, chat_id):
    chat, association, error = _chat_member_or_403(user_id, chat_id)
    if error:
        return error

    data = request.get_json() or {}
    if 'notifications_muted' not in data:
        return jsonify({'error': 'notifications_muted is required'}), 400

    association.notifications_muted = bool(data['notifications_muted'])
    db.session.commit()

    return jsonify({
        'success': True,
        'notificationsMuted': association.notifications_muted,
    }), 200


@chat_bp.route('/api/group_chats/<int:chat_id>/photo', methods=['POST'])
@token_required
def upload_group_chat_photo(user_id, chat_id):
    chat, _, error = _chat_member_or_403(user_id, chat_id)
    if error:
        return error

    if not _is_chat_creator(chat, user_id):
        return jsonify({'error': 'Only the creator can change chat photo'}), 403

    if 'photo' not in request.files:
        return jsonify({'error': 'Photo file is required'}), 400

    photo_file = request.files['photo']
    try:
        filename, _updated_at = save_chat_photo(chat_id, photo_file)
    except ValueError as exc:
        return jsonify({'error': str(exc)}), 400

    if chat.avatar_filename and chat.avatar_filename != filename:
        delete_chat_photo(chat.avatar_filename)

    chat.avatar_filename = filename
    db.session.commit()
    _emit_chat_updated(chat)

    return jsonify({
        'success': True,
        'photoUrl': _chat_photo_url(chat),
    }), 200


@chat_bp.route('/api/group_chats/<int:chat_id>/photo', methods=['GET'])
def get_group_chat_photo(chat_id):
    chat = GroupChat.query.get(chat_id)
    if not chat:
        return jsonify({'error': 'Chat not found'}), 404

    path = chat_photo_file_path(chat)
    if not path or not os.path.isfile(path):
        return jsonify({'error': 'Photo not found'}), 404

    return send_file(path, conditional=True)


@chat_bp.route('/api/group_chats/<int:chat_id>/messages', methods=['GET'])
@token_required
def get_group_chat_messages(user_id, chat_id):
    chat, _, error = _chat_member_or_403(user_id, chat_id)
    if error:
        return error

    after_id = request.args.get('after_id', type=int)
    messages = _serialize_messages(_load_chat_messages(chat, after_id=after_id))
    return jsonify({'messages': messages}), 200


def _purge_group_chat_data(chat_id):
    """Удаляет все данные чата с корректным порядком по FK."""
    route_shares = ChatRouteShare.query.filter_by(chat_id=chat_id).all()
    for route_share in route_shares:
        delete_route_share_file(route_share.stored_filename)
        if route_share.photo_filename:
            delete_route_share_photo(route_share.photo_filename)

    message_ids = db.session.scalars(
        select(GroupMessage.id).where(GroupMessage.chat_id == chat_id)
    ).all()

    if message_ids:
        MessageReaction.query.filter(
            MessageReaction.message_id.in_(message_ids)
        ).delete(synchronize_session=False)

    # group_message.route_share_id → chat_route_share: сначала отвязываем, потом удаляем.
    db.session.execute(
        update(GroupMessage)
        .where(GroupMessage.chat_id == chat_id)
        .values(route_share_id=None)
    )
    db.session.flush()

    GroupMessage.query.filter_by(chat_id=chat_id).delete(
        synchronize_session=False,
    )
    db.session.flush()

    ChatRouteShare.query.filter_by(chat_id=chat_id).delete(
        synchronize_session=False,
    )
    chat = GroupChat.query.get(chat_id)
    if chat and chat.avatar_filename:
        delete_chat_photo(chat.avatar_filename)
    UserGroupChatAssociation.query.filter_by(chat_id=chat_id).delete(
        synchronize_session=False,
    )
    db.session.flush()


@chat_bp.route('/api/group_chats/<int:chat_id>', methods=['DELETE'])
@token_required
def delete_group_chat(user_id, chat_id):
    chat = GroupChat.query.get(chat_id)
    if not chat:
        return jsonify({'error': 'Chat not found'}), 404

    if not _is_chat_creator(chat, user_id):
        return jsonify({'error': 'Only the creator can delete this chat'}), 403

    try:
        member_user_ids = db.session.scalars(
            select(UserGroupChatAssociation.user_id).where(
                UserGroupChatAssociation.chat_id == chat_id
            )
        ).all()
        _emit_chat_deleted(chat_id, member_user_ids)
        _purge_group_chat_data(chat_id)
        db.session.delete(chat)
        db.session.commit()
    except Exception as exc:
        db.session.rollback()
        current_app.logger.exception('Failed to delete group chat %s', chat_id)
        return jsonify({'error': 'Failed to delete chat', 'details': str(exc)}), 500

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
    now = _utcnow()
    rows = (
        db.session.query(UserGroupChatAssociation, GroupChat)
        .join(GroupChat, UserGroupChatAssociation.chat_id == GroupChat.id)
        .filter(
            UserGroupChatAssociation.user_id == user_id,
            UserGroupChatAssociation.invitation_seen_at.is_(None),
        )
        .all()
    )
    updated = 0
    for association, chat in rows:
        if chat.creator_id and chat.creator_id != user_id:
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

    snapshot = {}
    for key in (
        'activity_type',
        'distance',
        'duration_seconds',
        'elevation_gain_m',
        'avg_speed_kmh',
        'calories',
        'started_at',
        'description',
        'effort_level',
        'notes',
    ):
        raw = request.form.get(key)
        if raw is None or str(raw).strip() == '':
            continue
        snapshot[key] = raw

    tags = _parse_tags(request.form.get('tags'))
    if tags:
        snapshot['tags'] = tags

    photo_filename = None
    photo_file = request.files.get('photo')
    if photo_file and photo_file.filename:
        try:
            photo_filename = save_route_share_photo(photo_file)
        except ValueError as exc:
            return jsonify({'error': str(exc)}), 400

    try:
        original_filename, stored_filename, file_size = save_chat_route_file(file_storage)
    except ValueError as exc:
        if photo_filename:
            delete_route_share_photo(photo_filename)
        return jsonify({'error': str(exc)}), 400

    route_share = ChatRouteShare(
        chat_id=chat_id,
        uploader_id=user_id,
        original_filename=original_filename,
        stored_filename=stored_filename,
        title=title or original_filename,
        file_size=file_size,
        snapshot_json=json.dumps(snapshot, ensure_ascii=False) if snapshot else None,
        photo_filename=photo_filename,
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
    '/api/group_chats/<int:chat_id>/route_shares/<int:share_id>/photo',
    methods=['GET'],
)
@token_required
def download_route_share_photo(user_id, chat_id, share_id):
    _, _, error = _chat_member_or_403(user_id, chat_id)
    if error:
        return error

    route_share = ChatRouteShare.query.filter_by(
        id=share_id, chat_id=chat_id
    ).first()
    if not route_share or not route_share.photo_filename:
        return jsonify({'error': 'Photo not found'}), 404

    file_path = route_share_photo_path(route_share.photo_filename)
    if not file_path or not os.path.isfile(file_path):
        return jsonify({'error': 'Photo file is missing on server'}), 404

    return send_file(file_path)


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
