from models import Club, ClubMember, Friendship
from sqlalchemy import or_


def friend_ids(user_id):
    rows = Friendship.query.filter(
        Friendship.status == 'accepted',
        or_(
            Friendship.user_id == user_id,
            Friendship.friend_id == user_id,
        ),
    ).all()
    ids = set()
    for row in rows:
        if row.user_id == user_id:
            ids.add(row.friend_id)
        else:
            ids.add(row.user_id)
    return ids


def membership_for(user_id, club_id):
    return ClubMember.query.filter_by(user_id=user_id, club_id=club_id).first()


def is_club_moderator(user_id, club_id):
    membership = membership_for(user_id, club_id)
    return membership is not None and membership.role in {'owner', 'admin'}


def is_active_member(user_id, club_id):
    membership = membership_for(user_id, club_id)
    return membership is not None and membership.status == 'active'


def can_view_club(club_id, user_id):
    club = Club.query.get(club_id)
    if not club:
        return False
    if is_active_member(user_id, club_id):
        return True
    return club.privacy == 'open'


def can_post_in_club(club_id, user_id):
    club = Club.query.get(club_id)
    if not club or not is_active_member(user_id, club_id):
        return False
    if club.admins_only_posting:
        return is_club_moderator(user_id, club_id)
    return True


def active_member_club_ids(user_id):
    rows = ClubMember.query.filter_by(user_id=user_id, status='active').all()
    return [row.club_id for row in rows]


def feed_club_ids(user_id):
    club_ids = active_member_club_ids(user_id)
    if not club_ids:
        return []
    clubs = Club.query.filter(
        Club.id.in_(club_ids),
        Club.show_activity_feed.is_(True),
    ).all()
    return [club.id for club in clubs]


def can_view_moment(viewer_id, moment):
    if moment.club_id:
        club = Club.query.get(moment.club_id)
        if not club or not club.show_activity_feed:
            return False
        return can_view_club(moment.club_id, viewer_id)

    if viewer_id == moment.user_id:
        return True
    return moment.user_id in friend_ids(viewer_id)
