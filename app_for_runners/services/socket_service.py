from extensions import db
from models import User, GroupChat, GroupMessage, UserGroupChatAssociation
from services.jwt_service import verify_jwt

def init_socket_handlers(socketio):
    @socketio.on('join_chat')
    def handle_join_chat(data):
        token = data.get('token')
        user_id = verify_jwt(token)
        if not user_id:
            return

        chat_id = data.get('chat_id')
        user = User.query.get(user_id)
        chat = GroupChat.query.get(chat_id)
        if not chat or not UserGroupChatAssociation.query.filter_by(user_id=user_id, chat_id=chat_id).first():
            return

        socketio.join_room(chat_id)
        socketio.emit('joined', {'message': f'User {user.email} joined chat {chat_id}'}, room=chat_id)

    @socketio.on('send_message')
    def handle_send_message(data):
        token = data.get('token')
        user_id = verify_jwt(token)
        if not user_id:
            return

        chat_id = data.get('chat_id')
        content = data.get('content')
        if not content:
            return

        user = User.query.get(user_id)
        chat = GroupChat.query.get(chat_id)
        if not chat or not UserGroupChatAssociation.query.filter_by(user_id=user_id, chat_id=chat_id).first():
            return

        new_message = GroupMessage(chat_id=chat_id, sender_id=user_id, content=content)
        db.session.add(new_message)
        db.session.commit()

        message_data = {
            'id': new_message.id,
            'sender': user.email,
            'content': content,
            'timestamp': new_message.timestamp.isoformat()
        }
        socketio.emit('new_message', message_data, room=chat_id)
