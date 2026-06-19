from datetime import datetime, timedelta, timezone
from threading import Lock

from sqlalchemy import or_

from extensions import db
from models import Friendship, User

ONLINE_THRESHOLD = timedelta(seconds=90)
LAST_SEEN_UPDATE_INTERVAL = timedelta(seconds=30)

_lock = Lock()
_sid_user: dict[str, int] = {}
_user_sids: dict[int, set[str]] = {}


def _utcnow():
    return datetime.now(timezone.utc)


def _as_utc(value):
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)


def friend_ids_for_user(user_id):
    rows = Friendship.query.filter(
        Friendship.status == 'accepted',
        or_(Friendship.user_id == user_id, Friendship.friend_id == user_id),
    ).all()
    friend_ids = set()
    for row in rows:
        friend_ids.add(row.friend_id if row.user_id == user_id else row.user_id)
    return friend_ids


def register_user_socket(user_id, sid):
    with _lock:
        was_online = bool(_user_sids.get(user_id))
        _sid_user[sid] = user_id
        _user_sids.setdefault(user_id, set()).add(sid)
        return not was_online


def unregister_user_socket(sid):
    with _lock:
        user_id = _sid_user.pop(sid, None)
        if user_id is None:
            return None, False

        sids = _user_sids.get(user_id)
        if not sids:
            return user_id, False

        sids.discard(sid)
        if sids:
            return user_id, False

        _user_sids.pop(user_id, None)
        return user_id, True


def is_user_socket_connected(user_id):
    with _lock:
        return bool(_user_sids.get(user_id))


def is_user_online(user):
    if user is None:
        return False
    user_id = user.id_User
    if is_user_socket_connected(user_id):
        return True
    if user.last_seen_at is None:
        return False
    return (_utcnow() - _as_utc(user.last_seen_at)) <= ONLINE_THRESHOLD


def touch_user_last_seen(user_id):
    now = _utcnow()
    stale_before = now - LAST_SEEN_UPDATE_INTERVAL
    (
        User.query.filter(
            User.id_User == user_id,
            or_(
                User.last_seen_at.is_(None),
                User.last_seen_at < stale_before,
            ),
        ).update({User.last_seen_at: now}, synchronize_session=False)
    )
    db.session.commit()


def clear_user_last_seen(user_id):
    (
        User.query.filter(User.id_User == user_id).update(
            {User.last_seen_at: None},
            synchronize_session=False,
        )
    )
    db.session.commit()


def activate_user_presence(user_id, sid):
    became_online = register_user_socket(user_id, sid)
    touch_user_last_seen(user_id)
    if became_online:
        notify_friends_presence(user_id, True)
    return became_online


def deactivate_user_presence(sid):
    user_id, went_offline = unregister_user_socket(sid)
    if user_id is None:
        return
    if went_offline:
        clear_user_last_seen(user_id)
        notify_friends_presence(user_id, False)


def notify_friends_presence(user_id, is_online):
    from extensions import socketio

    payload = {'user_id': user_id, 'is_online': is_online}
    for friend_id in friend_ids_for_user(user_id):
        socketio.emit('presence_update', payload, room=f'user_{friend_id}')
