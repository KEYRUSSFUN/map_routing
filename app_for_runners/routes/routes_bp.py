# routes/routes_bp.py
from flask import Blueprint, request, jsonify
from utils.auth import token_required
from extensions import db
from models import Route
from datetime import datetime

routes_bp = Blueprint('routes', __name__)

@routes_bp.route('/api/routes', methods=['GET'])
@token_required
def get_routes(user_id):
    routes = Route.query.filter_by(id_User=user_id).all()
    result = []
    for route in routes:
        result.append({
            'id_Route': route.id_Route,
            'path': route.path,
            'creation_date': route.creation_date.strftime('%Y-%m-%d %H:%M:%S') if route.creation_date else None
        })
    return jsonify(result), 200

@routes_bp.route('/api/routes', methods=['POST'])
@token_required
def create_route(user_id):
    data = request.get_json()
    new_route = Route(
        id_User=user_id,
        path=data.get('path'),
        creation_date=datetime.now()
    )
    db.session.add(new_route)
    db.session.commit()
    return jsonify({'success': True, 'id': new_route.id_Route}), 200

@routes_bp.route('/api/routes/<int:route_id>', methods=['DELETE'])
@token_required
def delete_route(user_id, route_id):
    route = Route.query.filter_by(id_Route=route_id, id_User=user_id).first()
    if not route:
        return jsonify({'error': 'Route not found'}), 404
    db.session.delete(route)
    db.session.commit()
    return jsonify({'success': True}), 200