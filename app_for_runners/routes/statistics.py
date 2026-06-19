from flask import Blueprint, request, jsonify
from datetime import datetime
from extensions import db
from models import UserStatistic
from utils.auth import token_required
from utils.user_info_helper import ensure_user_info_exists

statistics_bp = Blueprint('statistics', __name__)

@statistics_bp.route('/api/user_statistic', methods=['POST'])
@token_required
def add_user_statistic(user_id):
    data = request.get_json()

    required_fields = ['calories', 'steps', 'distance', 'date']
    if not all(field in data for field in required_fields):
        return jsonify({'error': 'Missing fields'}), 400

    try:
        ensure_user_info_exists(user_id)
        date_obj = datetime.strptime(data['date'], '%Y-%m-%d').date()

        existing_stat = UserStatistic.query.filter_by(id_User=user_id, date=date_obj).first()

        if existing_stat:
            existing_stat.calories += data['calories']
            existing_stat.steps += data['steps']
            existing_stat.distance += data['distance']
        else:
            new_stat = UserStatistic(
                id_User=user_id,
                calories=data['calories'],
                steps=data['steps'],
                distance=data['distance'],
                date=date_obj
            )
            db.session.add(new_stat)

        db.session.commit()
        return jsonify({'success': True, 'message': 'Статистика обновлена'}), 201
    except Exception as e:
        return jsonify({'error': str(e)}), 500

def _serialize_user_statistics(target_user_id, date_str=None):
    if date_str:
        date = datetime.strptime(date_str, '%Y-%m-%d').date()
        stats = UserStatistic.query.filter_by(id_User=target_user_id, date=date).all()
    else:
        stats = UserStatistic.query.filter_by(id_User=target_user_id).order_by(
            UserStatistic.date.desc()
        ).all()

    return [{
        'calories': s.calories,
        'steps': s.steps,
        'distance': s.distance,
        'date': s.date.strftime('%Y-%m-%d')
    } for s in stats]


@statistics_bp.route('/api/user_statistic', methods=['GET'])
@token_required
def get_user_statistics(user_id):
    date_str = request.args.get('date')

    try:
        return jsonify(_serialize_user_statistics(user_id, date_str)), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@statistics_bp.route('/api/user_statistic/<int:target_user_id>', methods=['GET'])
@token_required
def get_user_statistics_by_id(user_id, target_user_id):
    date_str = request.args.get('date')

    try:
        return jsonify(_serialize_user_statistics(target_user_id, date_str)), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500
