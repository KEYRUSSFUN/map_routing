import os

from flask import Blueprint, request, jsonify, send_file
from extensions import db
from models import User, UserInfo
from utils.auth import token_required
from utils.avatar_storage import avatar_file_path, save_user_avatar
from utils.cover_storage import cover_file_path, save_user_cover
from utils.user_avatar import avatar_url_for
from utils.user_cover import ALLOWED_COVER_PRESETS, cover_url_for, is_valid_cover_preset

profile_bp = Blueprint('profile', __name__)


def _serialize_user_info(user_info):
    data = {
        "id": user_info.id_User,
        "name": user_info.name,
        "weight": user_info.weight,
        "height": user_info.height,
        "sex": user_info.sex,
        "age": user_info.Age,
        "country": user_info.country or "",
        "avatar_url": avatar_url_for(user_info),
        "cover_url": cover_url_for(user_info),
        "cover_preset": user_info.cover_preset,
    }

    return data


@profile_bp.route('/api/user_info/check', methods=['GET'])
@token_required
def check_user_info(user_id):
    user_info = UserInfo.query.filter_by(id_User=user_id).first()
    if user_info:
        return jsonify({"filled": True}), 200
    return jsonify({"filled": False}), 404


@profile_bp.route('/api/user_info', methods=['GET'])
@token_required
def get_user_info(user_id):
    user_info = UserInfo.query.filter_by(id_User=user_id).first()
    if user_info:
        return jsonify(_serialize_user_info(user_info)), 200
    return jsonify({"error": "User info not found"}), 404


@profile_bp.route('/api/user_info', methods=['POST'])
@token_required
def update_user_info(user_id):
    data = request.get_json()
    if not all(k in data for k in ['name', 'weight', 'height', 'sex', 'age', 'country']):
        return jsonify({"error": "Missing fields"}), 400

    country = (data.get('country') or '').strip()

    user_info = UserInfo.query.filter_by(id_User=user_id).first()
    if user_info:
        user_info.name = data['name']
        user_info.weight = data['weight']
        user_info.height = data['height']
        user_info.sex = data['sex']
        user_info.Age = data['age']
        user_info.country = country
    else:
        user_info = UserInfo(
            id_User=user_id,
            name=data['name'],
            weight=data['weight'],
            height=data['height'],
            sex=data['sex'],
            Age=data['age'],
            country=country,
        )
        db.session.add(user_info)

    db.session.commit()
    return jsonify({"success": True}), 200


@profile_bp.route('/api/user_info/avatar', methods=['POST'])
@token_required
def upload_user_avatar(user_id):
    if 'avatar' not in request.files:
        return jsonify({"error": "Avatar file is required"}), 400

    avatar_file = request.files['avatar']
    user_info = UserInfo.query.filter_by(id_User=user_id).first()
    if not user_info:
        return jsonify({"error": "User info not found"}), 404

    try:
        filename, updated_at = save_user_avatar(user_id, avatar_file)
    except ValueError as exc:
        return jsonify({"error": str(exc)}), 400

    user_info.avatar_filename = filename
    user_info.avatar_updated_at = updated_at
    db.session.commit()

    return jsonify({
        "success": True,
        "avatar_url": _serialize_user_info(user_info)["avatar_url"],
    }), 200


@profile_bp.route('/api/user_info/avatar/<int:user_id>', methods=['GET'])
def get_user_avatar(user_id):
    user_info = UserInfo.query.filter_by(id_User=user_id).first()
    if not user_info:
        return jsonify({"error": "User info not found"}), 404

    path = avatar_file_path(user_info)
    if not path or not os.path.isfile(path):
        return jsonify({"error": "Avatar not found"}), 404

    return send_file(path, conditional=True)


@profile_bp.route('/api/user_info/cover/preset', methods=['POST'])
@token_required
def set_user_cover_preset(user_id):
    data = request.get_json(silent=True) or {}
    preset = (data.get('cover_preset') or '').strip()

    if not is_valid_cover_preset(preset):
        allowed = ', '.join(sorted(ALLOWED_COVER_PRESETS))
        return jsonify({
            "error": f"Unknown cover preset. Allowed: {allowed}",
        }), 400

    user_info = UserInfo.query.filter_by(id_User=user_id).first()
    if not user_info:
        return jsonify({"error": "User info not found"}), 404

    user_info.cover_preset = preset
    user_info.cover_filename = None
    user_info.cover_updated_at = None
    db.session.commit()

    return jsonify({
        "success": True,
        **_serialize_user_info(user_info),
    }), 200


@profile_bp.route('/api/user_info/cover', methods=['POST'])
@token_required
def upload_user_cover(user_id):
    if 'cover' not in request.files:
        return jsonify({"error": "Cover file is required"}), 400

    cover_file = request.files['cover']
    user_info = UserInfo.query.filter_by(id_User=user_id).first()
    if not user_info:
        return jsonify({"error": "User info not found"}), 404

    try:
        filename, updated_at = save_user_cover(user_id, cover_file)
    except ValueError as exc:
        return jsonify({"error": str(exc)}), 400

    user_info.cover_filename = filename
    user_info.cover_updated_at = updated_at
    user_info.cover_preset = None
    db.session.commit()

    return jsonify({
        "success": True,
        **_serialize_user_info(user_info),
    }), 200


@profile_bp.route('/api/user_info/cover/<int:user_id>', methods=['GET'])
def get_user_cover(user_id):
    user_info = UserInfo.query.filter_by(id_User=user_id).first()
    if not user_info:
        return jsonify({"error": "User info not found"}), 404

    path = cover_file_path(user_info)
    if not path or not os.path.isfile(path):
        return jsonify({"error": "Cover not found"}), 404

    return send_file(path, conditional=True)


@profile_bp.route('/api/user_info/<int:target_user_id>', methods=['GET'])
@token_required
def get_user_info_by_id(user_id, target_user_id):
    user = User.query.get(target_user_id)
    if not user:
        return jsonify({'error': 'User not found'}), 404

    user_info = UserInfo.query.filter_by(id_User=target_user_id).first()
    if not user_info:
        return jsonify({'error': 'User info not found'}), 404

    return jsonify(_serialize_user_info(user_info)), 200
