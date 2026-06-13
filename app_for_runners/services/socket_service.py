from flask_socketio import emit, join_room

from extensions import db
from models import User, GroupChat, GroupMessage, UserGroupChatAssociation
from services.jwt_service import verify_jwt


def _parse_chat_id(raw_chat_id):
    if raw_chat_id is None:
        return None
    try:
        return int(raw_chat_id)
    except (TypeError, ValueError):
        return None


def _room_name(chat_id):
    return str(chat_id)


def init_socket_handlers(socketio):
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

        user = User.query.get(user_id)
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
            'sender_id': user_id,
            'sender': sender_name,
            'content': content,
            'message_type': 'text',
            'timestamp': new_message.timestamp.isoformat(),
            'reactions': [],
        }
        emit('new_message', message_data, room=_room_name(chat_id))
