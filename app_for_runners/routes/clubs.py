from datetime import datetime, timezone
import os

from flask import Blueprint, jsonify, request, send_file, url_for
from sqlalchemy import or_, and_

from extensions import db
from models import Club, ClubMember, GroupChat, GroupMessage, Moment, Route, User, UserGroupChatAssociation
from utils.auth import token_required
from utils.club_access import (
    active_member_club_ids,
    can_post_in_club,
    can_view_club,
    friend_ids,
    is_active_member,
    is_club_moderator,
    membership_for,
)
from utils.club_storage import (
    club_avatar_file_path,
    club_cover_file_path,
    delete_club_avatar,
    delete_club_cover,
    save_club_avatar,
    save_club_cover,
)

clubs_bp = Blueprint('clubs', __name__)

ALLOWED_SPORT_TYPES = frozenset(
    {
        'all_sports',
        'cycling',
        'running',
        'triathlon',
        'alpine_skiing',
    }
)
ALLOWED_CLUB_TYPES = frozenset(
    {
        'casual',
        'team',
        'brand',
        'company',
    }
)
ALLOWED_PRIVACY = frozenset({'open', 'closed'})
ALLOWED_LOCATION_SCOPES = frozenset({'worldwide', 'specific'})
ALLOWED_NOTIFICATION_LEVELS = frozenset({'all', 'announcements', 'off'})


def _membership_for(user_id, club_id):
    return membership_for(user_id, club_id)


def _is_club_admin(user_id, club_id):
    return is_club_moderator(user_id, club_id)


def _club_avatar_url(club, *, external=False):
    if not club or not club.avatar_filename:
        return None
    url = url_for('clubs.get_club_avatar', club_id=club.id, _external=external)
    path = club_avatar_file_path(club)
    version = int(os.path.getmtime(path)) if path and os.path.isfile(path) else 0
    return f'{url}?v={version}'


def _club_cover_url(club, *, external=False):
    if not club or not club.cover_filename:
        return None
    url = url_for('clubs.get_club_cover', club_id=club.id, _external=external)
    path = club_cover_file_path(club)
    version = int(os.path.getmtime(path)) if path and os.path.isfile(path) else 0
    return f'{url}?v={version}'


def _active_member_count(club_id):
    return ClubMember.query.filter_by(
        club_id=club_id,
        status='active',
    ).count()


def _pending_member_count(club_id):
    return ClubMember.query.filter_by(
        club_id=club_id,
        status='pending',
    ).count()


def _serialize_club(club, *, viewer_id=None):
    membership = _membership_for(viewer_id, club.id) if viewer_id else None
    is_member = membership is not None and membership.status == 'active'
    is_moderator = membership is not None and membership.role in {'owner', 'admin'}
    data = {
        'id': club.id,
        'title': club.title,
        'description': club.description or '',
        'sportType': club.sport_type,
        'clubType': club.club_type,
        'privacy': club.privacy,
        'locationScope': club.location_scope,
        'locationLabel': club.location_label,
        'profileLink': club.profile_link,
        'avatarUrl': _club_avatar_url(club),
        'coverUrl': _club_cover_url(club),
        'groupChatId': club.group_chat_id,
        'memberCount': _active_member_count(club.id),
        'pendingCount': _pending_member_count(club.id),
        'createdAt': club.created_at.isoformat() if club.created_at else None,
        'showActivityFeed': club.show_activity_feed,
        'showLeaderboards': club.show_leaderboards,
        'adminsOnlyPosting': club.admins_only_posting,
        'isOwner': membership.role == 'owner' if membership else False,
        'isAdmin': is_moderator,
        'isMember': is_member,
        'canPost': can_post_in_club(viewer_id, club.id) if viewer_id else False,
        'membershipStatus': membership.status if membership else None,
        'membershipRole': membership.role if membership else None,
        'notificationLevel': membership.notification_level if membership else None,
    }
    return data


def _validate_payload(data, *, existing_club=None):
    title = (data.get('title') or '').strip()
    if not title:
        raise ValueError('Название клуба обязательно')

    sport_type = (data.get('sport_type') or data.get('sportType') or '').strip()
    privacy = (data.get('privacy') or 'open').strip()
    location_label = (data.get('location_label') or data.get('locationLabel') or '').strip()
    description = (data.get('description') or '').strip()

    if sport_type not in ALLOWED_SPORT_TYPES:
        raise ValueError('Некорректный вид спорта')
    if privacy not in ALLOWED_PRIVACY:
        raise ValueError('Некорректная конфиденциальность')

    if existing_club is not None:
        club_type = existing_club.club_type or 'casual'
    else:
        club_type = 'casual'

    location_scope = 'specific' if location_label else 'worldwide'

    return {
        'title': title,
        'description': description or None,
        'sport_type': sport_type,
        'club_type': club_type,
        'privacy': privacy,
        'location_scope': location_scope,
        'location_label': location_label or None,
        'profile_link': None,
    }


@clubs_bp.route('/api/clubs', methods=['GET'])
@token_required
def list_clubs(user_id):
    memberships = ClubMember.query.filter_by(user_id=user_id).all()
    club_ids = [item.club_id for item in memberships if item.status == 'active']
    clubs = []
    if club_ids:
        clubs = Club.query.filter(Club.id.in_(club_ids)).order_by(Club.created_at.desc()).all()

    return jsonify({
        'clubs': [_serialize_club(club, viewer_id=user_id) for club in clubs],
    }), 200


@clubs_bp.route('/api/clubs/discover', methods=['GET'])
@token_required
def discover_clubs(user_id):
    query = (request.args.get('q') or '').strip()
    clubs_query = Club.query

    if query:
        pattern = f'%{query}%'
        clubs_query = clubs_query.filter(
            or_(
                Club.title.ilike(pattern),
                Club.description.ilike(pattern),
                Club.location_label.ilike(pattern),
            )
        )

    clubs = clubs_query.order_by(Club.created_at.desc()).limit(50).all()
    return jsonify({
        'clubs': [_serialize_club(club, viewer_id=user_id) for club in clubs],
    }), 200


@clubs_bp.route('/api/clubs/<int:club_id>', methods=['GET'])
@token_required
def get_club(user_id, club_id):
    club = Club.query.get(club_id)
    if not club:
        return jsonify({'error': 'Club not found'}), 404
    return jsonify(_serialize_club(club, viewer_id=user_id)), 200


@clubs_bp.route('/api/clubs', methods=['POST'])
@token_required
def create_club(user_id):
    if request.content_type and 'multipart/form-data' in request.content_type:
        payload = request.form.to_dict()
    else:
        payload = request.get_json(silent=True) or {}

    try:
        fields = _validate_payload(payload)
    except ValueError as exc:
        return jsonify({'error': str(exc)}), 400

    group_chat = GroupChat(title=fields['title'], creator_id=user_id)
    db.session.add(group_chat)
    db.session.flush()

    db.session.add(
        UserGroupChatAssociation(
            user_id=user_id,
            chat_id=group_chat.id,
            invitation_seen_at=datetime.now(timezone.utc),
        )
    )

    club = Club(
        creator_id=user_id,
        group_chat_id=group_chat.id,
        **fields,
    )
    db.session.add(club)
    db.session.flush()

    db.session.add(
        ClubMember(
            club_id=club.id,
            user_id=user_id,
            role='owner',
            status='active',
        )
    )

    avatar_file = request.files.get('avatar') or request.files.get('photo')
    if avatar_file and avatar_file.filename:
        try:
            filename, _ = save_club_avatar(club.id, avatar_file)
            club.avatar_filename = filename
        except ValueError as exc:
            db.session.rollback()
            return jsonify({'error': str(exc)}), 400

    cover_file = request.files.get('cover')
    if cover_file and cover_file.filename:
        try:
            filename, _ = save_club_cover(club.id, cover_file)
            club.cover_filename = filename
        except ValueError as exc:
            db.session.rollback()
            return jsonify({'error': str(exc)}), 400

    db.session.commit()
    return jsonify(_serialize_club(club, viewer_id=user_id)), 201


@clubs_bp.route('/api/clubs/<int:club_id>', methods=['PUT'])
@token_required
def update_club(user_id, club_id):
    club = Club.query.get(club_id)
    if not club:
        return jsonify({'error': 'Club not found'}), 404
    if not _is_club_admin(user_id, club_id):
        return jsonify({'error': 'Only club admin can edit club'}), 403

    if request.content_type and 'multipart/form-data' in request.content_type:
        payload = request.form.to_dict()
    else:
        payload = request.get_json(silent=True) or {}

    try:
        fields = _validate_payload({**{
            'title': club.title,
            'sport_type': club.sport_type,
            'privacy': club.privacy,
            'location_label': club.location_label or '',
            'description': club.description or '',
        }, **payload}, existing_club=club)
    except ValueError as exc:
        return jsonify({'error': str(exc)}), 400

    club.title = fields['title']
    club.description = fields['description']
    club.sport_type = fields['sport_type']
    club.club_type = fields['club_type']
    club.privacy = fields['privacy']
    club.location_scope = fields['location_scope']
    club.location_label = fields['location_label']
    club.profile_link = fields['profile_link']

    if club.group_chat:
        club.group_chat.title = fields['title']

    avatar_file = request.files.get('avatar') or request.files.get('photo')
    if avatar_file and avatar_file.filename:
        try:
            if club.avatar_filename:
                delete_club_avatar(club.avatar_filename)
            filename, _ = save_club_avatar(club.id, avatar_file)
            club.avatar_filename = filename
        except ValueError as exc:
            return jsonify({'error': str(exc)}), 400

    cover_file = request.files.get('cover')
    if cover_file and cover_file.filename:
        try:
            if club.cover_filename:
                delete_club_cover(club.cover_filename)
            filename, _ = save_club_cover(club.id, cover_file)
            club.cover_filename = filename
        except ValueError as exc:
            return jsonify({'error': str(exc)}), 400

    db.session.commit()
    return jsonify(_serialize_club(club, viewer_id=user_id)), 200


@clubs_bp.route('/api/clubs/<int:club_id>/join', methods=['POST'])
@token_required
def join_club(user_id, club_id):
    club = Club.query.get(club_id)
    if not club:
        return jsonify({'error': 'Club not found'}), 404

    existing = _membership_for(user_id, club_id)
    if existing:
        if existing.status == 'active':
            return jsonify({'message': 'Already a member', 'status': 'active'}), 200
        if existing.status == 'pending':
            return jsonify({'message': 'Request pending', 'status': 'pending'}), 200

    status = 'active' if club.privacy == 'open' else 'pending'
    db.session.add(
        ClubMember(
            club_id=club_id,
            user_id=user_id,
            role='member',
            status=status,
        )
    )

    if status == 'active' and club.group_chat_id:
        has_chat = UserGroupChatAssociation.query.filter_by(
            user_id=user_id,
            chat_id=club.group_chat_id,
        ).first()
        if not has_chat:
            db.session.add(
                UserGroupChatAssociation(
                    user_id=user_id,
                    chat_id=club.group_chat_id,
                )
            )

    db.session.commit()
    return jsonify({'status': status}), 200


@clubs_bp.route('/api/clubs/<int:club_id>/requests/<int:target_user_id>/approve', methods=['POST'])
@token_required
def approve_join_request(user_id, club_id, target_user_id):
    if not _is_club_admin(user_id, club_id):
        return jsonify({'error': 'Only club admin can approve requests'}), 403

    membership = _membership_for(target_user_id, club_id)
    if not membership or membership.status != 'pending':
        return jsonify({'error': 'Join request not found'}), 404

    membership.status = 'active'
    club = Club.query.get(club_id)
    if club and club.group_chat_id:
        has_chat = UserGroupChatAssociation.query.filter_by(
            user_id=target_user_id,
            chat_id=club.group_chat_id,
        ).first()
        if not has_chat:
            db.session.add(
                UserGroupChatAssociation(
                    user_id=target_user_id,
                    chat_id=club.group_chat_id,
                )
            )

    db.session.commit()
    return jsonify({'success': True}), 200


@clubs_bp.route('/api/clubs/<int:club_id>/avatar', methods=['GET'])
def get_club_avatar(club_id):
    club = Club.query.get(club_id)
    if not club:
        return jsonify({'error': 'Club not found'}), 404
    path = club_avatar_file_path(club)
    if not path:
        return jsonify({'error': 'Avatar not found'}), 404
    return send_file(path, conditional=True)


@clubs_bp.route('/api/clubs/<int:club_id>/cover', methods=['GET'])
def get_club_cover(club_id):
    club = Club.query.get(club_id)
    if not club:
        return jsonify({'error': 'Club not found'}), 404
    path = club_cover_file_path(club)
    if not path:
        return jsonify({'error': 'Cover not found'}), 404
    return send_file(path, conditional=True)


@clubs_bp.route('/api/clubs/<int:club_id>/members', methods=['GET'])
@token_required
def list_club_members(user_id, club_id):
    club = Club.query.get(club_id)
    if not club:
        return jsonify({'error': 'Club not found'}), 404
    if not can_view_club(club_id, user_id):
        return jsonify({'error': 'Access denied'}), 403

    from utils.user_avatar import avatar_url_for

    members = (
        ClubMember.query.filter_by(club_id=club_id, status='active')
        .order_by(ClubMember.joined_at.asc())
        .limit(50)
        .all()
    )
    payload = []
    for member in members:
        user = User.query.get(member.user_id)
        info = user.user_info if user else None
        payload.append({
            'userId': member.user_id,
            'name': info.name if info else f'User {member.user_id}',
            'avatarUrl': avatar_url_for(info),
            'location': info.country if info else '',
            'role': member.role,
            'isMe': member.user_id == user_id,
        })

    return jsonify({
        'members': payload,
        'total': _active_member_count(club_id),
    }), 200


@clubs_bp.route('/api/clubs/<int:club_id>/posts', methods=['GET'])
@token_required
def list_club_posts(user_id, club_id):
    club = Club.query.get(club_id)
    if not club:
        return jsonify({'error': 'Club not found'}), 404
    if not can_view_club(club_id, user_id) or not club.show_activity_feed:
        return jsonify({'error': 'Access denied'}), 403

    from routes.moments import _serialize_moments

    page = max(request.args.get('page', 1, type=int), 1)
    per_page = min(max(request.args.get('per_page', 20, type=int), 1), 50)
    query = Moment.query.filter_by(club_id=club_id).order_by(Moment.created_at.desc())
    total = query.count()
    moments = query.offset((page - 1) * per_page).limit(per_page).all()
    return jsonify({
        'posts': _serialize_moments(moments, user_id),
        'page': page,
        'per_page': per_page,
        'total': total,
        'has_more': page * per_page < total,
    }), 200


@clubs_bp.route('/api/clubs/<int:club_id>/posts', methods=['POST'])
@token_required
def create_club_post(user_id, club_id):
    club = Club.query.get(club_id)
    if not club:
        return jsonify({'error': 'Club not found'}), 404
    if not can_post_in_club(club_id, user_id):
        return jsonify({'error': 'Publishing is not allowed'}), 403

    from routes.moments import _serialize_moments
    from utils.moment_storage import save_moment_photo

    text = (request.form.get('text') or '').strip() or None
    if text and len(text) > 2000:
        return jsonify({'error': 'Text is too long'}), 400

    photo_filename = None
    created_at = datetime.now(timezone.utc)
    if 'photo' in request.files and request.files['photo'].filename:
        try:
            photo_filename, created_at = save_moment_photo(
                user_id,
                request.files['photo'],
            )
        except ValueError as exc:
            return jsonify({'error': str(exc)}), 400

    if not text and not photo_filename:
        return jsonify({'error': 'Add text or photo'}), 400

    moment = Moment(
        user_id=user_id,
        club_id=club_id,
        text=text,
        photo_filename=photo_filename,
        created_at=created_at,
    )
    db.session.add(moment)
    db.session.commit()
    return jsonify(_serialize_moments([moment], user_id)[0]), 201


@clubs_bp.route('/api/clubs/<int:club_id>/settings', methods=['PUT'])
@token_required
def update_club_settings(user_id, club_id):
    club = Club.query.get(club_id)
    if not club:
        return jsonify({'error': 'Club not found'}), 404
    if not _is_club_admin(user_id, club_id):
        return jsonify({'error': 'Only club admin can change settings'}), 403

    data = request.get_json(silent=True) or {}
    if 'showActivityFeed' in data:
        club.show_activity_feed = bool(data['showActivityFeed'])
    if 'showLeaderboards' in data:
        club.show_leaderboards = bool(data['showLeaderboards'])
    if 'adminsOnlyPosting' in data:
        club.admins_only_posting = bool(data['adminsOnlyPosting'])
    if 'privacy' in data and data['privacy'] in ALLOWED_PRIVACY:
        club.privacy = data['privacy']

    membership = _membership_for(user_id, club_id)
    notification = data.get('notificationLevel')
    if membership and notification in ALLOWED_NOTIFICATION_LEVELS:
        membership.notification_level = notification

    db.session.commit()
    return jsonify(_serialize_club(club, viewer_id=user_id)), 200


@clubs_bp.route('/api/clubs/<int:club_id>/leave', methods=['POST'])
@token_required
def leave_club(user_id, club_id):
    membership = _membership_for(user_id, club_id)
    if not membership or membership.status != 'active':
        return jsonify({'error': 'Not a member'}), 404
    if membership.role == 'owner':
        return jsonify({'error': 'Owner cannot leave the club'}), 400

    db.session.delete(membership)
    club = Club.query.get(club_id)
    if club and club.group_chat_id:
        assoc = UserGroupChatAssociation.query.filter_by(
            user_id=user_id,
            chat_id=club.group_chat_id,
        ).first()
        if assoc:
            db.session.delete(assoc)

    db.session.commit()
    return jsonify({'success': True}), 200


@clubs_bp.route('/api/clubs/<int:club_id>/weekly-stats', methods=['GET'])
@token_required
def club_weekly_stats(user_id, club_id):
    from datetime import timedelta
    from utils.user_avatar import avatar_url_for

    club = Club.query.get(club_id)
    if not club:
        return jsonify({'error': 'Club not found'}), 404
    if not can_view_club(club_id, user_id):
        return jsonify({'error': 'Access denied'}), 403
    if not club.show_leaderboards:
        return jsonify({'error': 'Leaderboards disabled'}), 403

    since = datetime.now(timezone.utc) - timedelta(days=7)

    member_ids = [
        row.user_id
        for row in ClubMember.query.filter_by(club_id=club_id, status='active').all()
    ]
    if not member_ids:
        return jsonify({
            'totalDistanceKm': 0,
            'workoutsCount': 0,
            'topDistanceKm': 0,
            'topElevationM': 0,
            'myDistanceKm': 0,
            'myElevationM': 0,
            'leaderboard': [],
        }), 200

    routes = Route.query.filter(
        Route.id_User.in_(member_ids),
        Route.creation_date >= since.replace(tzinfo=None),
    ).all()

    total_distance = 0.0
    my_distance = 0.0
    my_elevation = 0.0
    by_user = {}

    for route in routes:
        distance = float(route.distance or 0)
        elevation = float(route.elevation_gain_m or 0)
        total_distance += distance
        bucket = by_user.setdefault(route.id_User, {'distance': 0.0, 'elevation': 0.0})
        bucket['distance'] += distance
        bucket['elevation'] += elevation
        if route.id_User == user_id:
            my_distance += distance
            my_elevation += elevation

    leaderboard = []
    for member_id, stats in sorted(
        by_user.items(),
        key=lambda item: item[1]['distance'],
        reverse=True,
    )[:20]:
        user = User.query.get(member_id)
        info = user.user_info if user else None
        leaderboard.append({
            'userId': member_id,
            'name': info.name if info else f'User {member_id}',
            'avatarUrl': avatar_url_for(info),
            'distanceKm': round(stats['distance'], 1),
            'elevationM': round(stats['elevation'], 1),
        })

    top_distance = max((item['distanceKm'] for item in leaderboard), default=0)
    top_elevation = max((item['elevationM'] for item in leaderboard), default=0)

    return jsonify({
        'totalDistanceKm': round(total_distance, 1),
        'workoutsCount': len(routes),
        'topDistanceKm': top_distance,
        'topElevationM': top_elevation,
        'myDistanceKm': round(my_distance, 1),
        'myElevationM': round(my_elevation, 1),
        'leaderboard': leaderboard,
    }), 200


@clubs_bp.route('/api/clubs/<int:club_id>/workouts', methods=['GET'])
@token_required
def list_club_workouts(user_id, club_id):
    from routes.routes_bp import _serialize_route
    from utils.user_avatar import avatar_url_for

    club = Club.query.get(club_id)
    if not club:
        return jsonify({'error': 'Club not found'}), 404
    if not can_view_club(club_id, user_id):
        return jsonify({'error': 'Access denied'}), 403

    page = max(request.args.get('page', 1, type=int), 1)
    per_page = min(max(request.args.get('per_page', 20, type=int), 1), 50)

    member_ids = [
        row.user_id
        for row in ClubMember.query.filter_by(club_id=club_id, status='active').all()
    ]
    if not member_ids:
        return jsonify({
            'workouts': [],
            'page': page,
            'per_page': per_page,
            'total': 0,
            'has_more': False,
        }), 200

    viewer_friends = friend_ids(user_id)
    visible_friend_ids = viewer_friends.intersection(member_ids)

    routes_query = Route.query.filter(
        Route.id_User.in_(member_ids),
        or_(
            Route.privacy == 'everyone',
            and_(
                Route.privacy == 'friends',
                or_(
                    Route.id_User == user_id,
                    Route.id_User.in_(visible_friend_ids),
                ),
            ),
        ),
    ).order_by(Route.creation_date.desc())

    total = routes_query.count()
    routes = routes_query.offset((page - 1) * per_page).limit(per_page).all()

    workouts = []
    for route in routes:
        owner = User.query.get(route.id_User)
        info = owner.user_info if owner else None
        payload = _serialize_route(route)
        payload['userId'] = route.id_User
        payload['userName'] = info.name if info else f'User {route.id_User}'
        payload['avatarUrl'] = avatar_url_for(info)
        workouts.append(payload)

    return jsonify({
        'workouts': workouts,
        'page': page,
        'per_page': per_page,
        'total': total,
        'has_more': page * per_page < total,
    }), 200
