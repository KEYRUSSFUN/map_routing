from flask import Blueprint, request, jsonify
from extensions import db
from models import UserInfo
from utils.auth import token_required

profile_bp = Blueprint('profile', __name__)

@profile_bp.route('/api/user_info/check', methods=['GET'])
@token_required
def check_user_info(user_id):
    user_info = UserInfo.query.filter_by(id_User=user_id).first()
    if user_info:
        return jsonify({"filled": True}), 200
    else:
        return jsonify({"filled": False}), 200

@profile_bp.route('/api/user_info', methods=['GET'])
@token_required
def get_user_info(user_id):
    user_info = UserInfo.query.filter_by(id_User=user_id).first()
    if user_info:
        return jsonify({
            "id": user_info.id_User,
            "name": user_info.name,
            "weight": user_info.weight,
            "height": user_info.height,
            "sex": user_info.sex,
            "age": user_info.Age,
           # "country" : user_info.Country,
        }), 200
    else:
        return jsonify({"error": "User info not found"}), 404

@profile_bp.route('/api/user_info', methods=['POST'])
@token_required
def update_user_info(user_id):
    data = request.get_json()
    if not all(k in data for k in ['name', 'weight', 'height', 'sex', 'age']):
        return jsonify({"error": "Missing fields"}), 400

    user_info = UserInfo.query.filter_by(id_User=user_id).first()
    if user_info:
        user_info.name = data['name']
        user_info.weight = data['weight']
        user_info.height = data['height']
        user_info.sex = data['sex']
        user_info.Age = data['age']
        #user_info.Country = data['country']
    else:
        user_info = UserInfo(
            id_User=user_id,
            name=data['name'],
            weight=data['weight'],
            height=data['height'],
            sex=data['sex'],
            Age=data['age'],
            #Country=data['country'],
        )
        db.session.add(user_info)

    db.session.commit()
    return jsonify({"success": True}), 200

@profile_bp.route('/api/user_info/<int:user_id>', methods=['GET'])
@token_required
def get_user_info_by_id(user_id):
    user = User.query.get(user_id)
    if not user:
        return jsonify({'error': 'User not found'}), 404

    user_info = UserInfo.query.filter_by(id_User=user_id).first()
    if not user_info:
        return jsonify({'error': 'User info not found'}), 404

    return jsonify({
        "id": user_info.id_User,
        "name": user_info.name,
        "weight": user_info.weight,
        "height": user_info.height,
        "sex": user_info.sex,
        "age": user_info.Age,
        #"country": user_info.Country,
    }), 200
