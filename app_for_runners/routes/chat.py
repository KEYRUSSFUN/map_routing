from flask import Blueprint, request, jsonify
from extensions import db
from models import User, GroupChat, GroupMessage, UserGroupChatAssociation
from utils.auth import token_required
from sqlalchemy.exc import IntegrityError

chat_bp = Blueprint('chat', __name__)

@chat_bp.route('/api/group_chats', methods=['GET'])
@token_required
def get_group_chats(user_id):
    user = User.query.get(user_id)
    if not user:
        return jsonify({'error': 'User not found'}), 404

    chat_data = []
    for chat in user.group_chats:
        last_message = chat.messages.order_by(GroupMessage.timestamp.desc()).first()
        chat_data.append({
            'id': chat.id,
            'title': chat.title,
            'lastMessage': last_message.content if last_message else ''
        })

    return jsonify(chat_data), 200

@chat_bp.route('/api/group_chats', methods=['POST'])
@token_required
def create_group_chat(user_id):
    data = request.get_json()
    title = data.get('title')
    member_ids = data.get('members', [])

    if not title:
        return jsonify({'error': 'Название чата обязательно'}), 400

    new_chat = GroupChat(title=title)
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
                    db.session.add(UserGroupChatAssociation(user_id=member_id, chat_id=new_chat.id))

        db.session.commit()
        return jsonify({'message': 'Групповой чат создан', 'chat_id': new_chat.id}), 201
    except IntegrityError as e:
        db.session.rollback()
        return jsonify({'error': 'Чат с такими участниками уже существует или произошёл конфликт.'}), 409
    except Exception as e:
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

    new_assoc = UserGroupChatAssociation(user_id=user_id, chat_id=chat_id)
    db.session.add(new_assoc)
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

    db.session.add(UserGroupChatAssociation(user_id=new_user_id, chat_id=chat_id))
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

    participants = []
    for member in chat.members:
        if member.user_info:
            participants.append(member.user_info.name)
        else:
            participants.append(f"User {member.id_User}")

    messages = []
    for msg in chat.messages.order_by(GroupMessage.timestamp.asc()).all():
        sender_name = msg.sender.user_info.name if msg.sender.user_info else f"User {msg.sender.id_User}"
        messages.append({
            'id': msg.id,
            'content': msg.content,
            'sender': sender_name,
            'timestamp': msg.timestamp.isoformat()
        })

    return jsonify({
        'id': chat.id,
        'title': chat.title,
        'participants': participants,
        'messages': messages
    }), 200
