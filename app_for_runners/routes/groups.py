# routes/groups.py
from flask import Blueprint, request, jsonify
from utils.auth import token_required
from extensions import db
from models import GroupChat, UserGroupChatAssociation, GroupMessage
from datetime import datetime

groups_bp = Blueprint('groups', __name__)

@groups_bp.route('/api/groups', methods=['GET'])
@token_required
def get_groups(user_id):
    user = User.query.get(user_id)
    if not user:
        return jsonify({'error': 'User not found'}), 404
    
    groups_data = []
    for chat in user.group_chats:
        last_message = chat.messages.order_by(GroupMessage.timestamp.desc()).first()
        groups_data.append({
            'id': chat.id,
            'name': chat.title,
            'description': last_message.content[:50] if last_message else '',
            'lastMessage': last_message.content if last_message else ''
        })
    return jsonify(groups_data), 200

@groups_bp.route('/api/groups', methods=['POST'])
@token_required
def create_group(user_id):
    data = request.get_json()
    name = data.get('name')
    description = data.get('description', '')
    
    if not name:
        return jsonify({'error': 'Название группы обязательно'}), 400
    
    new_chat = GroupChat(title=name)
    db.session.add(new_chat)
    db.session.flush()
    
    # Добавляем создателя в группу
    db.session.add(UserGroupChatAssociation(user_id=user_id, chat_id=new_chat.id))
    db.session.commit()
    
    return jsonify({'success': True, 'id': new_chat.id}), 201

@groups_bp.route('/api/groups/<int:group_id>/messages', methods=['GET'])
@token_required
def get_messages(user_id, group_id):
    assoc = UserGroupChatAssociation.query.filter_by(user_id=user_id, chat_id=group_id).first()
    if not assoc:
        return jsonify({'error': 'Access denied'}), 403
    
    messages = GroupMessage.query.filter_by(chat_id=group_id).order_by(GroupMessage.timestamp.asc()).all()
    result = []
    for msg in messages:
        sender_name = msg.sender.user_info.name if msg.sender.user_info else f"User {msg.sender.id_User}"
        result.append({
            'id': msg.id,
            'text': msg.content,
            'sender': sender_name,
            'timestamp': msg.timestamp.isoformat()
        })
    return jsonify(result), 200

@groups_bp.route('/api/groups/<int:group_id>/messages', methods=['POST'])
@token_required
def send_message(user_id, group_id):
    assoc = UserGroupChatAssociation.query.filter_by(user_id=user_id, chat_id=group_id).first()
    if not assoc:
        return jsonify({'error': 'Access denied'}), 403
    
    data = request.get_json()
    text = data.get('text')
    
    if not text:
        return jsonify({'error': 'Message text required'}), 400
    
    new_message = GroupMessage(
        chat_id=group_id,
        sender_id=user_id,
        content=text,
        timestamp=datetime.now()
    )
    db.session.add(new_message)
    db.session.commit()
    
    return jsonify({'success': True, 'id': new_message.id}), 201