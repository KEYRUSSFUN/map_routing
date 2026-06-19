from datetime import datetime, timezone

from flask import Blueprint, jsonify, request, send_file
from sqlalchemy import func, or_

from extensions import db
from models import Friendship, Moment, MomentComment, MomentLike, User, UserInfo
from utils.auth import token_required
from utils.moment_storage import (
    delete_moment_photo,
    moment_photo_file_path,
    save_moment_photo,
)
from utils.user_avatar import avatar_url_for

moments_bp = Blueprint('moments', __name__)


def _utcnow():
    return datetime.now(timezone.utc)


def _friend_ids(user_id):
    rows = Friendship.query.filter(
        Friendship.status == 'accepted',
        or_(
            Friendship.user_id == user_id,
            Friendship.friend_id == user_id,
        ),
    ).all()
    friend_ids = set()
    for row in rows:
        if row.user_id == user_id:
            friend_ids.add(row.friend_id)
        else:
            friend_ids.add(row.user_id)
    return friend_ids


def _can_view_user_moments(viewer_id, owner_id):
    if viewer_id == owner_id:
        return True
    return owner_id in _friend_ids(viewer_id)


def _photo_url(moment):
    if not moment.photo_filename:
        return None
    from flask import url_for
    return url_for('moments.get_moment_photo', filename=moment.photo_filename)


def _user_info_map(user_ids):
    if not user_ids:
        return {}
    users = User.query.filter(User.id_User.in_(user_ids)).all()
    return {user.id_User: user for user in users}


def _engagement_maps(moment_ids, viewer_id):
    if not moment_ids:
        return {}, set(), {}

    like_rows = (
        db.session.query(MomentLike.moment_id, func.count())
        .filter(MomentLike.moment_id.in_(moment_ids))
        .group_by(MomentLike.moment_id)
        .all()
    )
    like_counts = {moment_id: count for moment_id, count in like_rows}

    viewer_likes = {
        row.moment_id
        for row in MomentLike.query.filter(
            MomentLike.moment_id.in_(moment_ids),
            MomentLike.user_id == viewer_id,
        ).all()
    }

    comment_rows = (
        db.session.query(MomentComment.moment_id, func.count())
        .filter(MomentComment.moment_id.in_(moment_ids))
        .group_by(MomentComment.moment_id)
        .all()
    )
    comment_counts = {moment_id: count for moment_id, count in comment_rows}

    return like_counts, viewer_likes, comment_counts


def _serialize_moment(moment, *, viewer_id, users_by_id, like_counts, viewer_likes, comment_counts):
    user = users_by_id.get(moment.user_id)
    info = user.user_info if user else None
    return {
        'id': moment.id,
        'user_id': moment.user_id,
        'user_name': info.name if info else 'Пользователь',
        'avatar_url': avatar_url_for(info),
        'text': moment.text,
        'photo_url': _photo_url(moment),
        'created_at': moment.created_at.isoformat(),
        'likes_count': int(like_counts.get(moment.id, 0)),
        'comments_count': int(comment_counts.get(moment.id, 0)),
        'liked_by_me': moment.id in viewer_likes,
        'is_me': moment.user_id == viewer_id,
    }


def _serialize_moments(moments, viewer_id):
    moment_ids = [moment.id for moment in moments]
    user_ids = {moment.user_id for moment in moments}
    users_by_id = _user_info_map(user_ids)
    like_counts, viewer_likes, comment_counts = _engagement_maps(moment_ids, viewer_id)
    return [
        _serialize_moment(
            moment,
            viewer_id=viewer_id,
            users_by_id=users_by_id,
            like_counts=like_counts,
            viewer_likes=viewer_likes,
            comment_counts=comment_counts,
        )
        for moment in moments
    ]


def _get_moment_or_404(moment_id):
    moment = Moment.query.get(moment_id)
    if not moment:
        return None
    return moment


@moments_bp.route('/api/moments/feed', methods=['GET'])
@token_required
def get_moments_feed(user_id):
    page = max(request.args.get('page', 1, type=int), 1)
    per_page = min(max(request.args.get('per_page', 20, type=int), 1), 50)
    visible_ids = {user_id, *_friend_ids(user_id)}

    query = (
        Moment.query.filter(Moment.user_id.in_(visible_ids))
        .order_by(Moment.created_at.desc())
    )
    total = query.count()
    moments = query.offset((page - 1) * per_page).limit(per_page).all()

    return jsonify({
        'moments': _serialize_moments(moments, user_id),
        'page': page,
        'per_page': per_page,
        'total': total,
        'has_more': page * per_page < total,
    }), 200


@moments_bp.route('/api/moments/me', methods=['GET'])
@token_required
def get_my_moments(user_id):
    moments = (
        Moment.query.filter_by(user_id=user_id)
        .order_by(Moment.created_at.desc())
        .all()
    )
    return jsonify(_serialize_moments(moments, user_id)), 200


@moments_bp.route('/api/moments/user/<int:target_user_id>', methods=['GET'])
@token_required
def get_user_moments(user_id, target_user_id):
    if not _can_view_user_moments(user_id, target_user_id):
        return jsonify({'error': 'Access denied'}), 403

    moments = (
        Moment.query.filter_by(user_id=target_user_id)
        .order_by(Moment.created_at.desc())
        .all()
    )
    return jsonify(_serialize_moments(moments, user_id)), 200


@moments_bp.route('/api/moments', methods=['POST'])
@token_required
def create_moment(user_id):
    text = (request.form.get('text') or '').strip() or None
    if text and len(text) > 2000:
        return jsonify({'error': 'Text is too long'}), 400

    photo_filename = None
    created_at = _utcnow()
    if 'photo' in request.files and request.files['photo'].filename:
        try:
            photo_filename, created_at = save_moment_photo(user_id, request.files['photo'])
        except ValueError as exc:
            return jsonify({'error': str(exc)}), 400

    if not text and not photo_filename:
        return jsonify({'error': 'Add text or photo'}), 400

    moment = Moment(
        user_id=user_id,
        text=text,
        photo_filename=photo_filename,
        created_at=created_at,
    )
    db.session.add(moment)
    db.session.commit()

    payload = _serialize_moments([moment], user_id)[0]
    return jsonify(payload), 201


@moments_bp.route('/api/moments/<int:moment_id>', methods=['DELETE'])
@token_required
def delete_moment(user_id, moment_id):
    moment = _get_moment_or_404(moment_id)
    if not moment:
        return jsonify({'error': 'Moment not found'}), 404
    if moment.user_id != user_id:
        return jsonify({'error': 'Access denied'}), 403

    delete_moment_photo(moment)
    db.session.delete(moment)
    db.session.commit()
    return jsonify({'message': 'Moment deleted'}), 200


@moments_bp.route('/api/moments/<int:moment_id>/like', methods=['POST'])
@token_required
def toggle_moment_like(user_id, moment_id):
    moment = _get_moment_or_404(moment_id)
    if not moment:
        return jsonify({'error': 'Moment not found'}), 404
    if not _can_view_user_moments(user_id, moment.user_id):
        return jsonify({'error': 'Access denied'}), 403

    existing = MomentLike.query.filter_by(
        moment_id=moment_id,
        user_id=user_id,
    ).first()

    liked = False
    if existing:
        db.session.delete(existing)
    else:
        db.session.add(MomentLike(moment_id=moment_id, user_id=user_id))
        liked = True

    db.session.commit()
    likes_count = MomentLike.query.filter_by(moment_id=moment_id).count()

    return jsonify({'liked': liked, 'likes_count': likes_count}), 200


@moments_bp.route('/api/moments/<int:moment_id>/comments', methods=['GET'])
@token_required
def get_moment_comments(user_id, moment_id):
    moment = _get_moment_or_404(moment_id)
    if not moment:
        return jsonify({'error': 'Moment not found'}), 404
    if not _can_view_user_moments(user_id, moment.user_id):
        return jsonify({'error': 'Access denied'}), 403

    comments = (
        MomentComment.query.filter_by(moment_id=moment_id)
        .order_by(MomentComment.created_at.asc())
        .all()
    )
    user_ids = {comment.user_id for comment in comments}
    users_by_id = _user_info_map(user_ids)

    payload = []
    for comment in comments:
        user = users_by_id.get(comment.user_id)
        info = user.user_info if user else None
        payload.append({
            'id': comment.id,
            'user_id': comment.user_id,
            'user_name': info.name if info else 'Пользователь',
            'avatar_url': avatar_url_for(info),
            'text': comment.text,
            'created_at': comment.created_at.isoformat(),
            'is_me': comment.user_id == user_id,
        })

    return jsonify(payload), 200


@moments_bp.route('/api/moments/<int:moment_id>/comments', methods=['POST'])
@token_required
def add_moment_comment(user_id, moment_id):
    moment = _get_moment_or_404(moment_id)
    if not moment:
        return jsonify({'error': 'Moment not found'}), 404
    if not _can_view_user_moments(user_id, moment.user_id):
        return jsonify({'error': 'Access denied'}), 403

    data = request.get_json(silent=True) or {}
    text = (data.get('text') or '').strip()
    if not text:
        return jsonify({'error': 'Comment text is required'}), 400
    if len(text) > 1000:
        return jsonify({'error': 'Comment is too long'}), 400

    comment = MomentComment(
        moment_id=moment_id,
        user_id=user_id,
        text=text,
        created_at=_utcnow(),
    )
    db.session.add(comment)
    db.session.commit()

    user = User.query.get(user_id)
    info = user.user_info if user else None
    comments_count = MomentComment.query.filter_by(moment_id=moment_id).count()

    return jsonify({
        'comment': {
            'id': comment.id,
            'user_id': comment.user_id,
            'user_name': info.name if info else 'Пользователь',
            'avatar_url': avatar_url_for(info),
            'text': comment.text,
            'created_at': comment.created_at.isoformat(),
            'is_me': True,
        },
        'comments_count': comments_count,
    }), 201


@moments_bp.route('/api/moments/photos/<filename>', methods=['GET'])
def get_moment_photo(filename):
    moment = Moment.query.filter_by(photo_filename=filename).first()
    if not moment:
        return jsonify({'error': 'Photo not found'}), 404

    path = moment_photo_file_path(moment)
    if not path:
        return jsonify({'error': 'Photo not found'}), 404
    return send_file(path, conditional=True)
