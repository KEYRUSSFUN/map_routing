# routes/routes_bp.py
import json
import os
from datetime import datetime

from flask import Blueprint, request, jsonify, send_file, url_for
from utils.auth import token_required
from extensions import db
from models import Route
from utils.workout_photo_storage import save_workout_photo, workout_photo_file_path

routes_bp = Blueprint('routes', __name__)


def _parse_tags(raw):
    if raw is None:
        return []
    if isinstance(raw, list):
        return [str(item).strip() for item in raw if str(item).strip()]
    if isinstance(raw, str):
        text = raw.strip()
        if not text:
            return []
        try:
            parsed = json.loads(text)
            if isinstance(parsed, list):
                return [str(item).strip() for item in parsed if str(item).strip()]
        except json.JSONDecodeError:
            return [part.strip() for part in text.split(',') if part.strip()]
    return []


def _parse_started_at(value):
    if not value:
        return None
    if isinstance(value, datetime):
        return value
    text = str(value).strip()
    if not text:
        return None
    if text.endswith('Z'):
        text = text[:-1] + '+00:00'
    try:
        return datetime.fromisoformat(text)
    except ValueError:
        return None


def _workout_photo_url(route):
    if not route or not route.photo_filename:
        return None
    return url_for('routes.get_route_photo', route_id=route.id_Route)


def _serialize_route(route):
    return {
        'id_Route': route.id_Route,
        'path': route.path,
        'creation_date': route.creation_date.strftime('%Y-%m-%d %H:%M:%S')
        if route.creation_date
        else None,
        'title': route.title,
        'activity_type': route.activity_type,
        'description': route.description,
        'tags': _parse_tags(route.tags),
        'effort_level': route.effort_level,
        'notes': route.notes,
        'privacy': route.privacy,
        'distance': route.distance,
        'duration_seconds': route.duration_seconds,
        'calories': route.calories,
        'elevation_gain_m': route.elevation_gain_m,
        'avg_speed_kmh': route.avg_speed_kmh,
        'started_at': route.started_at.isoformat() if route.started_at else None,
        'photo_url': _workout_photo_url(route),
    }


@routes_bp.route('/api/routes', methods=['GET'])
@token_required
def get_routes(user_id):
    routes = Route.query.filter_by(id_User=user_id).all()
    return jsonify([_serialize_route(route) for route in routes]), 200


@routes_bp.route('/api/routes', methods=['POST'])
@token_required
def create_route(user_id):
    data = request.get_json() or {}
    path = data.get('path')
    if not path:
        return jsonify({'error': 'path is required'}), 400
    if isinstance(path, dict):
        path = json.dumps(path, ensure_ascii=False)

    tags = data.get('tags')
    tags_json = json.dumps(_parse_tags(tags)) if tags is not None else None

    new_route = Route(
        id_User=user_id,
        path=path,
        creation_date=datetime.now(),
        title=(data.get('title') or '').strip() or None,
        activity_type=(data.get('activity_type') or '').strip() or None,
        description=(data.get('description') or '').strip() or None,
        tags=tags_json,
        effort_level=data.get('effort_level'),
        notes=(data.get('notes') or '').strip() or None,
        privacy=(data.get('privacy') or '').strip() or None,
        distance=data.get('distance'),
        duration_seconds=data.get('duration_seconds'),
        calories=data.get('calories'),
        elevation_gain_m=data.get('elevation_gain_m'),
        avg_speed_kmh=data.get('avg_speed_kmh'),
        started_at=_parse_started_at(data.get('started_at')),
        started_at_local_hour=data.get('started_at_local_hour'),
    )
    db.session.add(new_route)
    db.session.commit()
    return jsonify({'success': True, 'id': new_route.id_Route, 'route': _serialize_route(new_route)}), 200


@routes_bp.route('/api/routes/<int:route_id>/photo', methods=['POST'])
@token_required
def upload_route_photo(user_id, route_id):
    route = Route.query.filter_by(id_Route=route_id, id_User=user_id).first()
    if not route:
        return jsonify({'error': 'Route not found'}), 404

    if 'photo' not in request.files:
        return jsonify({'error': 'Photo file is required'}), 400

    photo_file = request.files['photo']
    try:
        filename, _updated_at = save_workout_photo(route_id, photo_file)
    except ValueError as exc:
        return jsonify({'error': str(exc)}), 400

    route.photo_filename = filename
    db.session.commit()

    return jsonify({
        'success': True,
        'photo_url': _workout_photo_url(route),
    }), 200


@routes_bp.route('/api/routes/<int:route_id>/photo', methods=['GET'])
def get_route_photo(route_id):
    route = Route.query.filter_by(id_Route=route_id).first()
    if not route:
        return jsonify({'error': 'Route not found'}), 404

    path = workout_photo_file_path(route)
    if not path or not os.path.isfile(path):
        return jsonify({'error': 'Photo not found'}), 404

    return send_file(path, conditional=True)


_ALLOWED_PRIVACY = frozenset({'everyone', 'friends', 'private'})


def _normalize_privacy(value):
    if value is None:
        return None
    text = str(value).strip()
    return text if text in _ALLOWED_PRIVACY else None


def _normalize_effort(value):
    if value is None:
        return None
    try:
        level = int(value)
    except (TypeError, ValueError):
        return None
    return level if 1 <= level <= 5 else None


@routes_bp.route('/api/routes/<int:route_id>', methods=['PATCH'])
@token_required
def update_route(user_id, route_id):
    route = Route.query.filter_by(id_Route=route_id, id_User=user_id).first()
    if not route:
        return jsonify({'error': 'Route not found'}), 404

    data = request.get_json(silent=True) or {}

    if 'title' in data:
        route.title = (data.get('title') or '').strip() or None

    if 'description' in data:
        route.description = (data.get('description') or '').strip() or None

    if 'tags' in data:
        route.tags = json.dumps(_parse_tags(data.get('tags')))

    if 'effort_level' in data:
        effort = _normalize_effort(data.get('effort_level'))
        if effort is None and data.get('effort_level') is not None:
            return jsonify({'error': 'effort_level must be between 1 and 5'}), 400
        route.effort_level = effort

    if 'privacy' in data:
        privacy = _normalize_privacy(data.get('privacy'))
        if privacy is None and data.get('privacy') is not None:
            return jsonify({'error': 'Invalid privacy value'}), 400
        route.privacy = privacy

    if 'notes' in data:
        route.notes = (data.get('notes') or '').strip() or None

    db.session.commit()
    return jsonify({'success': True, 'route': _serialize_route(route)}), 200


@routes_bp.route('/api/routes/<int:route_id>', methods=['DELETE'])
@token_required
def delete_route(user_id, route_id):
    route = Route.query.filter_by(id_Route=route_id, id_User=user_id).first()
    if not route:
        return jsonify({'error': 'Route not found'}), 404

    photo_path = workout_photo_file_path(route)
    if photo_path and os.path.isfile(photo_path):
        try:
            os.remove(photo_path)
        except OSError:
            pass

    db.session.delete(route)
    db.session.commit()
    return jsonify({'success': True}), 200
