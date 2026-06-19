from datetime import datetime, timedelta, timezone

from flask import Blueprint, jsonify, request, send_file
from sqlalchemy import and_, or_

from extensions import db
from models import Friendship, Story, StoryView, User, UserInfo
from utils.auth import token_required
from utils.story_storage import delete_story_media, save_story_media, story_media_file_path
from utils.presence import is_user_online
from utils.user_avatar import avatar_url_for

stories_bp = Blueprint('stories', __name__)


def _utcnow():
    return datetime.now(timezone.utc)


def _story_ttl():
    from flask import current_app
    hours = current_app.config.get('STORY_TTL_HOURS', 24)
    return timedelta(hours=hours)


def _purge_expired_stories():
    now = _utcnow()
    expired = Story.query.filter(Story.expires_at <= now).all()
    if not expired:
        return
    for story in expired:
        delete_story_media(story)
        db.session.delete(story)
    db.session.commit()


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


def _can_view_user_stories(viewer_id, owner_id):
    if viewer_id == owner_id:
        return True
    return owner_id in _friend_ids(viewer_id)


def _media_url(story):
    from flask import url_for
    return url_for('stories.get_story_media', filename=story.media_filename)


def _serialize_story(story, *, viewer_id, viewed_story_ids):
    return {
        'id': story.id,
        'media_url': _media_url(story),
        'caption': story.caption,
        'created_at': story.created_at.isoformat(),
        'expires_at': story.expires_at.isoformat(),
        'is_viewed': story.id in viewed_story_ids,
    }


def _user_display(user):
    info = user.user_info
    return {
        'user_id': user.id_User,
        'name': info.name if info else 'Пользователь',
        'avatar_url': avatar_url_for(info),
    }


def _active_stories_for_users(user_ids):
    now = _utcnow()
    if not user_ids:
        return []
    return (
        Story.query.filter(
            Story.user_id.in_(user_ids),
            Story.expires_at > now,
        )
        .order_by(Story.created_at.asc())
        .all()
    )


def _viewed_story_ids(viewer_id, story_ids):
    if not story_ids:
        return set()
    rows = StoryView.query.filter(
        StoryView.viewer_id == viewer_id,
        StoryView.story_id.in_(story_ids),
    ).all()
    return {row.story_id for row in rows}


@stories_bp.route('/api/stories/feed', methods=['GET'])
@token_required
def get_stories_feed(user_id):
    _purge_expired_stories()

    user = User.query.get(user_id)
    if not user:
        return jsonify({'error': 'User not found'}), 404

    friend_ids = sorted(_friend_ids(user_id))
    friends = User.query.filter(User.id_User.in_(friend_ids)).all() if friend_ids else []
    friends_by_id = {friend.id_User: friend for friend in friends}

    all_user_ids = [user_id, *friend_ids]
    stories = _active_stories_for_users(all_user_ids)
    stories_by_user = {}
    for story in stories:
        stories_by_user.setdefault(story.user_id, []).append(story)

    all_story_ids = [story.id for story in stories]
    viewed_ids = _viewed_story_ids(user_id, all_story_ids)

    def build_entry(target_user, *, is_me):
        uid = target_user.id_User
        user_stories = stories_by_user.get(uid, [])
        has_story = bool(user_stories)
        has_unviewed = any(story.id not in viewed_ids for story in user_stories)
        entry = _user_display(target_user)
        entry.update({
            'is_me': is_me,
            'has_story': has_story,
            'has_unviewed': has_unviewed,
            'story_count': len(user_stories),
            'is_online': False if is_me else is_user_online(target_user),
        })
        return entry

    me_entry = build_entry(user, is_me=True)

    friend_entries = []
    for fid in friend_ids:
        friend = friends_by_id.get(fid)
        if friend is None:
            continue
        friend_entries.append(build_entry(friend, is_me=False))

    friend_entries.sort(
        key=lambda item: (
            0 if item['has_unviewed'] else 1 if item['has_story'] else 2,
            item['name'].casefold(),
        )
    )

    return jsonify({'users': [me_entry, *friend_entries]}), 200


@stories_bp.route('/api/stories/me', methods=['GET'])
@token_required
def get_my_stories(user_id):
    _purge_expired_stories()
    stories = _active_stories_for_users([user_id])
    viewed_ids = _viewed_story_ids(user_id, [story.id for story in stories])
    return jsonify([
        _serialize_story(story, viewer_id=user_id, viewed_story_ids=viewed_ids)
        for story in stories
    ]), 200


@stories_bp.route('/api/stories/user/<int:target_user_id>', methods=['GET'])
@token_required
def get_user_stories(user_id, target_user_id):
    _purge_expired_stories()

    if not _can_view_user_stories(user_id, target_user_id):
        return jsonify({'error': 'Access denied'}), 403

    target = User.query.get(target_user_id)
    if not target:
        return jsonify({'error': 'User not found'}), 404

    stories = _active_stories_for_users([target_user_id])
    viewed_ids = _viewed_story_ids(user_id, [story.id for story in stories])
    payload = _user_display(target)
    payload['stories'] = [
        _serialize_story(story, viewer_id=user_id, viewed_story_ids=viewed_ids)
        for story in stories
    ]
    return jsonify(payload), 200


@stories_bp.route('/api/stories', methods=['POST'])
@token_required
def create_story(user_id):
    _purge_expired_stories()

    if 'media' not in request.files:
        return jsonify({'error': 'Story image is required'}), 400

    media_file = request.files['media']
    caption = (request.form.get('caption') or '').strip() or None
    if caption and len(caption) > 500:
        return jsonify({'error': 'Caption is too long'}), 400

    try:
        filename, created_at = save_story_media(user_id, media_file)
    except ValueError as exc:
        return jsonify({'error': str(exc)}), 400

    story = Story(
        user_id=user_id,
        media_filename=filename,
        caption=caption,
        created_at=created_at,
        expires_at=created_at + _story_ttl(),
    )
    db.session.add(story)
    db.session.commit()

    return jsonify(
        _serialize_story(story, viewer_id=user_id, viewed_story_ids=set())
    ), 201


@stories_bp.route('/api/stories/<int:story_id>/view', methods=['POST'])
@token_required
def mark_story_viewed(user_id, story_id):
    _purge_expired_stories()

    story = Story.query.get(story_id)
    if not story or story.expires_at <= _utcnow():
        return jsonify({'error': 'Story not found'}), 404

    if not _can_view_user_stories(user_id, story.user_id):
        return jsonify({'error': 'Access denied'}), 403

    existing = StoryView.query.filter_by(
        story_id=story_id,
        viewer_id=user_id,
    ).first()
    if existing is None:
        db.session.add(
            StoryView(
                story_id=story_id,
                viewer_id=user_id,
                viewed_at=_utcnow(),
            )
        )
        db.session.commit()

    return jsonify({'message': 'ok'}), 200


@stories_bp.route('/api/stories/<int:story_id>', methods=['DELETE'])
@token_required
def delete_story(user_id, story_id):
    story = Story.query.get(story_id)
    if not story:
        return jsonify({'error': 'Story not found'}), 404
    if story.user_id != user_id:
        return jsonify({'error': 'Access denied'}), 403

    delete_story_media(story)
    db.session.delete(story)
    db.session.commit()
    return jsonify({'message': 'Story deleted'}), 200


@stories_bp.route('/api/stories/media/<filename>', methods=['GET'])
def get_story_media(filename):
    story = Story.query.filter_by(media_filename=filename).first()
    if not story or story.expires_at <= _utcnow():
        return jsonify({'error': 'Story not found'}), 404

    path = story_media_file_path(story)
    if not path:
        return jsonify({'error': 'Story not found'}), 404
    return send_file(path, conditional=True)
