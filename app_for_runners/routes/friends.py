from flask import Blueprint, request, jsonify
from extensions import db
from models import User, Friendship, UserInfo
from utils.auth import token_required

friends_bp = Blueprint('friends', __name__)

@friends_bp.route('/api/friends', methods=['GET'])
@token_required
def get_friends(user_id):
    user = User.query.get(user_id)
    if not user:
        return jsonify({'error': 'User not found'}), 404

    friends = user.get_friends()
    friend_list = [{
        'id': friend.id_User,
        'email': friend.email,
        'name': friend.user_info.name if friend.user_info else None
    } for friend in friends]

    return jsonify(friend_list), 200

@friends_bp.route('/api/friends/requests', methods=['GET'])
@token_required
def get_friend_requests(user_id):
    try:
        requests = Friendship.query.filter_by(friend_id=user_id, status='pending').all()
        request_list = [
            {
                'id': req.id,
                'fromUserId': req.user_id,
                'fromUserName': UserInfo.query.get(req.user_id).name if UserInfo.query.get(req.user_id) else 'Неизвестный пользователь'
            } for req in requests
        ]
        return jsonify(request_list), 200
    except Exception as e:
        return jsonify({'error': 'Internal server error', 'details': str(e)}), 500

@friends_bp.route('/api/friends/reject_request', methods=['POST'])
@token_required
def reject_friend_request(user_id):
    try:
        data = request.get_json()
        request_id = data.get('request_id')
        if not request_id:
            return jsonify({'error': 'Request ID is required'}), 400

        request = Friendship.query.get(request_id)
        if not request or request.to_user_id != user_id or request.status != 'pending':
            return jsonify({'error': 'Invalid request'}), 400

        request.status = 'rejected'
        db.session.commit()

        return jsonify({'message': 'Friend request rejected'}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': 'Internal server error', 'details': str(e)}), 500

@friends_bp.route('/api/users/search', methods=['GET'])
@token_required
def search_users(user_id):
    try:
        query = request.args.get('name', '')
        if not query:
            return jsonify({'error': 'Name query parameter is required'}), 400

        users = UserInfo.query.filter(UserInfo.name.ilike(f'%{query}%')).all()
        user_list = []
        for user in users:
            user_dict = {
                'id': user.id_User,
                'name': user.name
            }
            user_list.append(user_dict)

        if not user_list:
            return jsonify([]), 200
        return jsonify(user_list), 200
    except Exception as e:
        return jsonify({'error': 'Internal server error', 'details': str(e)}), 500

@friends_bp.route('/api/friends/send_request', methods=['POST'])
@token_required
def send_friend_request(user_id):
    data = request.get_json()
    friend_id = data.get('friend_id')

    if not friend_id or not User.query.get(friend_id):
        return jsonify({'error': 'Invalid friend ID'}), 400

    if user_id == friend_id:
        return jsonify({'error': 'Cannot send friend request to yourself'}), 400

    existing = Friendship.query.filter_by(user_id=user_id, friend_id=friend_id).first()
    if existing:
        return jsonify({'error': 'Friend request already sent'}), 400

    reverse = Friendship.query.filter_by(user_id=friend_id, friend_id=user_id).first()
    if reverse and reverse.status == 'accepted':
        return jsonify({'error': 'Already friends'}), 400

    new_friendship = Friendship(user_id=user_id, friend_id=friend_id, status='pending')
    db.session.add(new_friendship)
    db.session.commit()

    return jsonify({'message': 'Friend request sent', 'friend_id': friend_id}), 201

@friends_bp.route('/api/friends/accept_request', methods=['POST'])
@token_required
def accept_friend_request(user_id):
    data = request.get_json()
    friend_id = data.get('friend_id')
    if not friend_id or not User.query.get(friend_id):
        return jsonify({'error': 'Invalid friend ID'}), 400

    friendship = Friendship.query.filter_by(user_id=friend_id, friend_id=user_id, status='pending').first()
    if not friendship:
        return jsonify({'error': 'No pending friend request found'}), 404

    friendship.status = 'accepted'
    db.session.commit()

    reverse_friendship = Friendship.query.filter_by(user_id=user_id, friend_id=friend_id).first()
    if not reverse_friendship:
        db.session.add(Friendship(user_id=user_id, friend_id=friend_id, status='accepted'))
        db.session.commit()

    return jsonify({'message': 'Friend request accepted', 'friend_id': friend_id}), 200
