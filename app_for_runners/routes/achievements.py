from datetime import datetime, timezone

from flask import Blueprint, jsonify, request

from extensions import db
from models import UserAchievement
from services.achievement_evaluator import ALLOWED_ACHIEVEMENT_IDS, evaluate_achievement_candidates
from utils.auth import token_required

achievements_bp = Blueprint('achievements', __name__)


def _serialize(row):
    return {
        'achievement_id': row.achievement_id,
        'unlocked_at': row.unlocked_at.replace(tzinfo=timezone.utc).isoformat(),
    }


def _fetch_user_achievements(user_id):
    return UserAchievement.query.filter_by(id_User=user_id).order_by(
        UserAchievement.unlocked_at.desc()
    ).all()


def _parse_unlocked_at(value):
    if not value:
        return datetime.now(timezone.utc)
    parsed = datetime.fromisoformat(value.replace('Z', '+00:00'))
    if parsed.tzinfo is None:
        return parsed.replace(tzinfo=timezone.utc)
    return parsed.astimezone(timezone.utc)


def _apply_achievement_candidates(user_id, candidates):
    existing = {
        row.achievement_id: row
        for row in UserAchievement.query.filter_by(id_User=user_id).all()
    }
    newly_unlocked = []

    for item in candidates:
        if not isinstance(item, dict):
            continue

        achievement_id = item.get('achievement_id')
        if not achievement_id or achievement_id not in ALLOWED_ACHIEVEMENT_IDS:
            continue
        if achievement_id in existing:
            continue

        row = UserAchievement(
            id_User=user_id,
            achievement_id=achievement_id,
            unlocked_at=_parse_unlocked_at(item.get('unlocked_at')),
        )
        db.session.add(row)
        existing[achievement_id] = row
        newly_unlocked.append(row)

    if newly_unlocked:
        db.session.commit()

    return newly_unlocked


@achievements_bp.route('/api/user_achievements', methods=['GET'])
@token_required
def get_user_achievements(user_id):
    rows = _fetch_user_achievements(user_id)
    return jsonify([_serialize(row) for row in rows]), 200


@achievements_bp.route('/api/user_achievements/<int:target_user_id>', methods=['GET'])
@token_required
def get_user_achievements_by_id(user_id, target_user_id):
    rows = _fetch_user_achievements(target_user_id)
    return jsonify([_serialize(row) for row in rows]), 200


@achievements_bp.route('/api/user_achievements/sync', methods=['POST'])
@token_required
def sync_user_achievements(user_id):
    data = request.get_json(silent=True) or {}
    items = data.get('achievements')

    if items is None:
        candidates = evaluate_achievement_candidates(user_id)
    elif not isinstance(items, list):
        return jsonify({'error': 'achievements must be a list'}), 400
    else:
        # Устаревший клиент: игнорируем локальные кандидаты, считаем на сервере.
        candidates = evaluate_achievement_candidates(user_id)

    newly_unlocked = _apply_achievement_candidates(user_id, candidates)
    all_rows = _fetch_user_achievements(user_id)
    return jsonify({
        'all': [_serialize(row) for row in all_rows],
        'newly_unlocked': [_serialize(row) for row in newly_unlocked],
    }), 200
