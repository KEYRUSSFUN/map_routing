from flask import request
from flask_socketio import emit, join_room

from extensions import db
from models import User, GroupChat, GroupMessage, UserGroupChatAssociation
from services.jwt_service import verify_jwt
from utils.presence import activate_user_presence, deactivate_user_presence
from utils.datetime_utils import utc_isoformat
from utils.user_avatar import avatar_url_for
from sqlalchemy.orm import joinedload


def _parse_chat_id(raw_chat_id):
    if raw_chat_id is None:
        return None
    try:
        return int(raw_chat_id)
    except (TypeError, ValueError):
        return None


def _room_name(chat_id):
    return str(chat_id)


def _user_room(user_id):
    return f'user_{user_id}'


def init_socket_handlers(socketio):
    @socketio.on('disconnect')
    def handle_disconnect():
        deactivate_user_presence(request.sid)

    @socketio.on('join_user')
    def handle_join_user(data):
        token = data.get('token')
        user_id = verify_jwt(token)
        if not user_id:
            emit('error', {'message': 'Invalid token'})
            return

        join_room(_user_room(user_id))
        activate_user_presence(user_id, request.sid)
        emit('joined_user', {'user_id': user_id})

    @socketio.on('join_chat')
    def handle_join_chat(data):
        token = data.get('token')
        user_id = verify_jwt(token)
        if not user_id:
            emit('error', {'message': 'Invalid token'})
            return

        chat_id = _parse_chat_id(data.get('chat_id'))
        if chat_id is None:
            emit('error', {'message': 'Invalid chat_id'})
            return

        user = User.query.get(user_id)
        chat = GroupChat.query.get(chat_id)
        if not chat or not UserGroupChatAssociation.query.filter_by(
            user_id=user_id, chat_id=chat_id
        ).first():
            emit('error', {'message': 'Access denied'})
            return

        room = _room_name(chat_id)
        join_room(room)
        emit(
            'joined',
            {'message': f'User {user.email} joined chat {chat_id}', 'chat_id': chat_id},
            room=room,
        )

    @socketio.on('send_message')
    def handle_send_message(data):
        token = data.get('token')
        user_id = verify_jwt(token)
        if not user_id:
            emit('error', {'message': 'Invalid token'})
            return

        chat_id = _parse_chat_id(data.get('chat_id'))
        content = (data.get('content') or '').strip()
        if chat_id is None or not content:
            emit('error', {'message': 'Invalid message payload'})
            return

        user = User.query.options(joinedload(User.user_info)).get(user_id)
        chat = GroupChat.query.get(chat_id)
        if not chat or not UserGroupChatAssociation.query.filter_by(
            user_id=user_id, chat_id=chat_id
        ).first():
            emit('error', {'message': 'Access denied'})
            return

        sender_name = (
            user.user_info.name if user.user_info else f'User {user.id_User}'
        )

        new_message = GroupMessage(chat_id=chat_id, sender_id=user_id, content=content)
        db.session.add(new_message)
        db.session.commit()

        message_data = {
            'id': new_message.id,
            'chat_id': chat_id,
            'sender_id': user_id,
            'sender': sender_name,
            'sender_avatar_url': avatar_url_for(user.user_info, external=False)
            if user.user_info
            else None,
            'content': content,
            'message_type': 'text',
            'timestamp': utc_isoformat(new_message.timestamp),
            'reactions': [],
        }
        emit('new_message', message_data, room=_room_name(chat_id))

    @socketio.on('typing')
    def handle_typing(data):
        token = data.get('token')
        user_id = verify_jwt(token)
        if not user_id:
            emit('error', {'message': 'Invalid token'})
            return

        chat_id = _parse_chat_id(data.get('chat_id'))
        if chat_id is None:
            emit('error', {'message': 'Invalid chat_id'})
            return

        chat = GroupChat.query.get(chat_id)
        if not chat or not UserGroupChatAssociation.query.filter_by(
            user_id=user_id, chat_id=chat_id
        ).first():
            emit('error', {'message': 'Access denied'})
            return

        user = User.query.options(joinedload(User.user_info)).get(user_id)
        sender_name = (
            user.user_info.name if user and user.user_info else f'User {user_id}'
        )
        is_typing = bool(data.get('typing', True))

        emit(
            'user_typing',
            {
                'chat_id': chat_id,
                'user_id': user_id,
                'sender': sender_name,
                'typing': is_typing,
            },
            room=_room_name(chat_id),
        )

    @socketio.on('join_all_chats')
    def handle_join_all_chats(data):
        token = data.get('token')
        user_id = verify_jwt(token)
        if not user_id:
            emit('error', {'message': 'Invalid token'})
            return

        join_room(_user_room(user_id))
        activate_user_presence(user_id, request.sid)
        associations = UserGroupChatAssociation.query.filter_by(user_id=user_id).all()
        chat_ids = []
        for association in associations:
            chat_id = association.chat_id
            join_room(_room_name(chat_id))
            chat_ids.append(chat_id)

        emit('joined_all', {'chat_ids': chat_ids})
