from datetime import date, datetime, timedelta, timezone
import calendar

from flask import Blueprint, jsonify
from sqlalchemy import func

from extensions import db
from models import Challenge, ChallengeParticipant, Friendship, UserInfo, UserStatistic
from utils.auth import token_required
from utils.user_avatar import avatar_url_for

challenges_bp = Blueprint('challenges', __name__)
_default_challenges_ready = False


def _utcnow():
    return datetime.now(timezone.utc)


def _today():
    return _utcnow().date()


def _metric_field(metric_type):
    return 'steps' if metric_type == 'steps' else 'distance'


def _progress_for_user(challenge, user_id, joined_at=None):
    metric = _metric_field(challenge.metric_type)
    start = challenge.start_date
    if joined_at is not None:
        joined_date = joined_at.astimezone(timezone.utc).date()
        if joined_date > start:
            start = joined_date
    end = min(challenge.end_date, _today())
    if end < start:
        return 0.0

    total = (
        db.session.query(func.coalesce(func.sum(getattr(UserStatistic, metric)), 0.0))
        .filter(
            UserStatistic.id_User == user_id,
            UserStatistic.date >= start,
            UserStatistic.date <= end,
        )
        .scalar()
    )
    total = float(total or 0.0)
    if metric == 'distance':
        return total / 1000.0
    return total


def _bulk_progress(challenge, participants):
    if not participants:
        return {}

    metric = _metric_field(challenge.metric_type)
    end = min(challenge.end_date, _today())
    user_ids = [participant.id_User for participant in participants]
    if end < challenge.start_date:
        return {user_id: 0.0 for user_id in user_ids}

    stats = UserStatistic.query.filter(
        UserStatistic.id_User.in_(user_ids),
        UserStatistic.date >= challenge.start_date,
        UserStatistic.date <= end,
    ).all()
    stats_by_user = {}
    for stat in stats:
        stats_by_user.setdefault(stat.id_User, []).append(stat)

    progress = {}
    for participant in participants:
        start = challenge.start_date
        if participant.joined_at is not None:
            joined_date = participant.joined_at.astimezone(timezone.utc).date()
            if joined_date > start:
                start = joined_date
        if end < start:
            progress[participant.id_User] = 0.0
            continue

        total = 0.0
        for stat in stats_by_user.get(participant.id_User, []):
            if start <= stat.date <= end:
                total += float(getattr(stat, metric) or 0)
        if metric == 'distance':
            total /= 1000.0
        progress[participant.id_User] = total
    return progress


def _participant_counts(challenge_ids):
    if not challenge_ids:
        return {}
    rows = (
        db.session.query(
            ChallengeParticipant.challenge_id,
            func.count(ChallengeParticipant.id_User),
        )
        .filter(ChallengeParticipant.challenge_id.in_(challenge_ids))
        .group_by(ChallengeParticipant.challenge_id)
        .all()
    )
    return {challenge_id: count for challenge_id, count in rows}


def _user_info_map(user_ids):
    if not user_ids:
        return {}
    rows = UserInfo.query.filter(UserInfo.id_User.in_(user_ids)).all()
    return {row.id_User: row for row in rows}


def _serialize_participant(challenge, user_id, progress, rank, user_info=None):
    if user_info is None:
        user_info = UserInfo.query.get(user_id)
    return {
        'user_id': user_id,
        'name': user_info.name if user_info and user_info.name else 'Пользователь',
        'avatar_url': avatar_url_for(user_info),
        'progress': round(progress, 2),
        'rank': rank,
    }


def _days_remaining(challenge):
    remaining = (challenge.end_date - _today()).days
    return max(0, remaining)


def _status_label(challenge):
    today = _today()
    if today < challenge.start_date:
        days = (challenge.start_date - today).days
        if days == 1:
            return 'Старт через 1 день'
        return f'Старт через {days} дн.'
    if today > challenge.end_date:
        return 'Завершён'
    remaining = _days_remaining(challenge)
    if remaining == 0:
        return 'Последний день'
    if remaining == 1:
        return 'Остался 1 день'
    if (challenge.end_date - challenge.start_date).days >= 27:
        return 'Открыт весь месяц'
    return f'Осталось {remaining} дн.'


def _participants_count(challenge_id):
    return ChallengeParticipant.query.filter_by(challenge_id=challenge_id).count()


def _is_joined(challenge_id, user_id):
    return (
        ChallengeParticipant.query.filter_by(
            challenge_id=challenge_id,
            id_User=user_id,
        ).first()
        is not None
    )


def _friend_ids(user_id):
    outgoing = Friendship.query.filter_by(user_id=user_id, status='accepted').all()
    incoming = Friendship.query.filter_by(friend_id=user_id, status='accepted').all()
    ids = {row.friend_id for row in outgoing}
    ids.update(row.user_id for row in incoming)
    return ids


def _leaderboard(challenge, participants=None, *, limit=10):
    if participants is None:
        participants = ChallengeParticipant.query.filter_by(
            challenge_id=challenge.id
        ).all()
    progress_map = _bulk_progress(challenge, participants)
    user_info_map = _user_info_map([row.id_User for row in participants])
    scored = [
        (row.id_User, progress_map.get(row.id_User, 0.0), row.joined_at)
        for row in participants
    ]
    scored.sort(key=lambda item: (-item[1], item[2]))
    result = []
    for index, (participant_id, progress, _) in enumerate(scored[:limit], start=1):
        result.append(
            _serialize_participant(
                challenge,
                participant_id,
                progress,
                index,
                user_info_map.get(participant_id),
            )
        )
    return result


def _friends_progress(challenge, user_id, participants=None, progress_map=None):
    friend_ids = _friend_ids(user_id)
    if not friend_ids:
        return []

    if participants is None:
        participants = ChallengeParticipant.query.filter_by(
            challenge_id=challenge.id
        ).all()
    if progress_map is None:
        progress_map = _bulk_progress(challenge, participants)

    friend_participants = [
        row for row in participants if row.id_User in friend_ids
    ]
    scored = [
        (row.id_User, progress_map.get(row.id_User, 0.0), row.joined_at)
        for row in friend_participants
    ]
    scored.sort(key=lambda item: (-item[1], item[2]))

    all_scored = sorted(
        [
            (row.id_User, progress_map.get(row.id_User, 0.0), row.joined_at)
            for row in participants
        ],
        key=lambda item: (-item[1], item[2]),
    )
    rank_by_user = {
        participant_id: index + 1
        for index, (participant_id, _, _) in enumerate(all_scored)
    }
    user_info_map = _user_info_map([participant_id for participant_id, _, _ in scored])

    return [
        _serialize_participant(
            challenge,
            participant_id,
            progress,
            rank_by_user.get(participant_id, 0),
            user_info_map.get(participant_id),
        )
        for participant_id, progress, _ in scored
    ]


def _serialize_challenge_summary(
    challenge,
    user_id,
    *,
    joined_ids=None,
    participant_counts=None,
    user_participation=None,
    progress_map=None,
):
    joined = (
        challenge.id in joined_ids
        if joined_ids is not None
        else _is_joined(challenge.id, user_id)
    )
    my_progress = None
    if joined:
        participant = user_participation
        if participant is None:
            participant = ChallengeParticipant.query.filter_by(
                challenge_id=challenge.id,
                id_User=user_id,
            ).first()
        if participant is not None:
            if progress_map is not None:
                my_progress = progress_map.get(user_id)
            else:
                my_progress = _progress_for_user(
                    challenge,
                    user_id,
                    participant.joined_at,
                )

    participants_count = (
        participant_counts.get(challenge.id, 0)
        if participant_counts is not None
        else _participants_count(challenge.id)
    )

    return {
        'id': challenge.id,
        'title': challenge.title,
        'description': challenge.description,
        'metric_type': challenge.metric_type,
        'target_value': challenge.target_value,
        'start_date': challenge.start_date.isoformat(),
        'end_date': challenge.end_date.isoformat(),
        'icon_key': challenge.icon_key,
        'participants_count': participants_count,
        'is_joined': joined,
        'my_progress': round(my_progress, 2) if my_progress is not None else None,
        'status_label': _status_label(challenge),
        'days_remaining': _days_remaining(challenge),
    }


def _get_challenge_or_404(challenge_id):
    challenge = Challenge.query.filter_by(id=challenge_id, is_active=True).first()
    return challenge


def ensure_default_challenges():
    global _default_challenges_ready
    if _default_challenges_ready:
        return
    if Challenge.query.count() > 0:
        _default_challenges_ready = True
        return

    today = _today()
    month_last_day = calendar.monthrange(today.year, today.month)[1]
    defaults = [
        Challenge(
            title='Недельный забег 25 км',
            description='Пробегите 25 км за неделю вместе с сообществом.',
            metric_type='distance',
            target_value=25.0,
            start_date=today - timedelta(days=7),
            end_date=today + timedelta(days=7),
            icon_key='running',
            is_active=True,
        ),
        Challenge(
            title='Городской велоспринт',
            description='Проедьте 50 км на велосипеде за две недели.',
            metric_type='distance',
            target_value=50.0,
            start_date=today + timedelta(days=1),
            end_date=today + timedelta(days=15),
            icon_key='cycling',
            is_active=True,
        ),
        Challenge(
            title='Шаговый марафон',
            description='Наберите 300 000 шагов за месяц.',
            metric_type='steps',
            target_value=300000.0,
            start_date=today.replace(day=1),
            end_date=today.replace(day=month_last_day),
            icon_key='steps',
            is_active=True,
        ),
    ]
    for row in defaults:
        db.session.add(row)
    db.session.commit()
    _default_challenges_ready = True


@challenges_bp.route('/api/challenges', methods=['GET'])
@token_required
def list_challenges(user_id):
    challenges = Challenge.query.filter_by(is_active=True).order_by(
        Challenge.start_date.desc()
    ).all()
    challenge_ids = [challenge.id for challenge in challenges]
    participant_counts = _participant_counts(challenge_ids)
    user_participations = {
        row.challenge_id: row
        for row in ChallengeParticipant.query.filter(
            ChallengeParticipant.challenge_id.in_(challenge_ids),
            ChallengeParticipant.id_User == user_id,
        ).all()
    }
    joined_ids = set(user_participations.keys())
    progress_by_challenge = {}
    for challenge_id, participation in user_participations.items():
        challenge = next(item for item in challenges if item.id == challenge_id)
        progress_by_challenge[challenge_id] = _bulk_progress(
            challenge,
            [participation],
        ).get(user_id, 0.0)

    return jsonify([
        _serialize_challenge_summary(
            challenge,
            user_id,
            joined_ids=joined_ids,
            participant_counts=participant_counts,
            user_participation=user_participations.get(challenge.id),
            progress_map={user_id: progress_by_challenge[challenge.id]}
            if challenge.id in progress_by_challenge
            else None,
        )
        for challenge in challenges
    ]), 200


@challenges_bp.route('/api/challenges/<int:challenge_id>/join', methods=['POST'])
@token_required
def join_challenge(user_id, challenge_id):
    challenge = _get_challenge_or_404(challenge_id)
    if challenge is None:
        return jsonify({'error': 'Челлендж не найден'}), 404

    today = _today()
    if today > challenge.end_date:
        return jsonify({'error': 'Челлендж уже завершён'}), 400

    existing = ChallengeParticipant.query.filter_by(
        challenge_id=challenge_id,
        id_User=user_id,
    ).first()
    if existing:
        return jsonify({'success': True, 'already_joined': True}), 200

    participant = ChallengeParticipant(
        challenge_id=challenge_id,
        id_User=user_id,
        joined_at=_utcnow(),
    )
    db.session.add(participant)
    db.session.commit()
    return jsonify({'success': True, 'already_joined': False}), 201


@challenges_bp.route('/api/challenges/<int:challenge_id>/leave', methods=['POST'])
@token_required
def leave_challenge(user_id, challenge_id):
    challenge = _get_challenge_or_404(challenge_id)
    if challenge is None:
        return jsonify({'error': 'Челлендж не найден'}), 404

    participant = ChallengeParticipant.query.filter_by(
        challenge_id=challenge_id,
        id_User=user_id,
    ).first()
    if participant is None:
        return jsonify({'error': 'Вы не участвуете в этом челлендже'}), 404

    db.session.delete(participant)
    db.session.commit()
    return jsonify({'success': True}), 200


@challenges_bp.route('/api/challenges/<int:challenge_id>', methods=['GET'])
@token_required
def get_challenge_details(user_id, challenge_id):
    challenge = _get_challenge_or_404(challenge_id)
    if challenge is None:
        return jsonify({'error': 'Челлендж не найден'}), 404

    if not _is_joined(challenge_id, user_id):
        return jsonify({'error': 'Сначала примите участие в челлендже'}), 403

    participant = ChallengeParticipant.query.filter_by(
        challenge_id=challenge_id,
        id_User=user_id,
    ).first()
    participants = ChallengeParticipant.query.filter_by(
        challenge_id=challenge_id,
    ).all()
    progress_map = _bulk_progress(challenge, participants)
    my_progress = progress_map.get(user_id, 0.0)

    payload = _serialize_challenge_summary(
        challenge,
        user_id,
        joined_ids={challenge_id},
        user_participation=participant,
        progress_map=progress_map,
    )
    payload.update({
        'my_progress': round(my_progress, 2),
        'top_participants': _leaderboard(challenge, participants, limit=10),
        'friends_progress': _friends_progress(
            challenge,
            user_id,
            participants=participants,
            progress_map=progress_map,
        ),
    })
    return jsonify(payload), 200
