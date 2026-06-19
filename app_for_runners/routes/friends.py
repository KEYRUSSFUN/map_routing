from flask import Blueprint, request, jsonify
from extensions import db
from models import User, Friendship, UserInfo
from utils.auth import token_required
from utils.presence import is_user_online
from utils.user_avatar import avatar_url_for
from datetime import datetime, timezone
from sqlalchemy import and_, or_
from sqlalchemy.orm import joinedload

friends_bp = Blueprint('friends', __name__)


def _utcnow():
    return datetime.now(timezone.utc)


def _relationship_status_map(current_user_id, target_user_ids):
    if not target_user_ids:
        return {}

    friendships = Friendship.query.filter(
        or_(
            and_(
                Friendship.user_id == current_user_id,
                Friendship.friend_id.in_(target_user_ids),
            ),
            and_(
                Friendship.friend_id == current_user_id,
                Friendship.user_id.in_(target_user_ids),
            ),
        )
    ).all()

    status_by_user = {target_id: 'none' for target_id in target_user_ids}
    for row in friendships:
        other_id = row.friend_id if row.user_id == current_user_id else row.user_id
        if row.status == 'accepted':
            status_by_user[other_id] = 'friend'
        elif row.status == 'pending':
            if row.user_id == current_user_id:
                status_by_user[other_id] = 'pending_outgoing'
            else:
                status_by_user[other_id] = 'pending_incoming'
    return status_by_user


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
        'name': friend.user_info.name if friend.user_info else None,
        'avatar_url': avatar_url_for(friend.user_info),
        'is_online': is_user_online(friend),
    } for friend in friends]

    return jsonify(friend_list), 200


@friends_bp.route('/api/friends/requests', methods=['GET'])
@token_required
def get_friend_requests(user_id):
    try:
        requests = (
            Friendship.query.filter_by(friend_id=user_id, status='pending')
            .options(joinedload(Friendship.user).joinedload(User.user_info))
            .all()
        )
        request_list = []
        unread_count = 0
        for req in requests:
            sender_info = req.user.user_info if req.user else None
            is_unread = req.viewed_at is None
            if is_unread:
                unread_count += 1
            request_list.append({
                'id': req.id,
                'fromUserId': req.user_id,
                'fromUserName': sender_info.name if sender_info else 'Неизвестный пользователь',
                'fromUserAvatarUrl': avatar_url_for(sender_info),
                'isUnread': is_unread,
            })
        return jsonify({
            'requests': request_list,
            'unreadCount': unread_count,
        }), 200
    except Exception as e:
        return jsonify({'error': 'Internal server error', 'details': str(e)}), 500


@friends_bp.route('/api/friends/requests/mark_seen', methods=['POST'])
@token_required
def mark_friend_requests_seen(user_id):
    try:
        now = _utcnow()
        pending_requests = Friendship.query.filter_by(
            friend_id=user_id, status='pending'
        ).all()
        for req in pending_requests:
            req.viewed_at = now
        db.session.commit()
        return jsonify({'message': 'Friend requests marked as seen', 'unreadCount': 0}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': 'Internal server error', 'details': str(e)}), 500


@friends_bp.route('/api/friends/reject_request', methods=['POST'])
@token_required
def reject_friend_request(user_id):
    try:
        data = request.get_json() or {}
        friend_id = data.get('friend_id')
        if not friend_id:
            return jsonify({'error': 'Friend ID is required'}), 400

        friendship = Friendship.query.filter_by(
            user_id=friend_id, friend_id=user_id, status='pending'
        ).first()
        if not friendship:
            return jsonify({'error': 'Invalid request'}), 400

        friendship.status = 'rejected'
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

        users = (
            UserInfo.query
            .filter(UserInfo.name.ilike(f'%{query}%'))
            .limit(20)
            .all()
        )
        filtered_users = [user for user in users if user.id_User != user_id]
        status_by_user = _relationship_status_map(
            user_id,
            [user.id_User for user in filtered_users],
        )
        user_list = []
        for user in filtered_users:
            user_list.append({
                'id': user.id_User,
                'name': user.name,
                'avatar_url': avatar_url_for(user),
                'relationshipStatus': status_by_user.get(user.id_User, 'none'),
            })

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
        if existing.status == 'accepted':
            return jsonify({'error': 'Already friends'}), 400
        if existing.status == 'pending':
            return jsonify({'error': 'Friend request already sent'}), 400

    reverse = Friendship.query.filter_by(user_id=friend_id, friend_id=user_id).first()
    if reverse and reverse.status == 'accepted':
        return jsonify({'error': 'Already friends'}), 400
    if reverse and reverse.status == 'pending':
        return jsonify({'error': 'Friend request already received'}), 400

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
