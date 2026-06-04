from flask import Blueprint, request, jsonify, session
from werkzeug.security import check_password_hash, generate_password_hash
from flask_login import login_user, logout_user
from extensions import db
from models import User
from services import generate_jwt, verify_jwt
from utils.auth import token_required

auth_bp = Blueprint('auth', __name__)

@auth_bp.route('/login', methods=['POST'])
def login_page():
    if request.method == 'POST':
        item = request.get_json()
        email = item['email']
        password = item['password']
        if email and password:
            user = User.query.filter_by(email=email).first()
            if user and check_password_hash(user.password, password):
                login_user(user)
                session['id_User'] = user.id_User
                token = generate_jwt(user.id_User)
                return jsonify({'success': True,'message': 'Вход успешен', 'token': token}), 201
            else:
                return jsonify({'success': False,'message': 'Не удалось войти'}), 201
        else:
            return jsonify({'success': False,'message': 'Заполните поля для входа'}), 201
    return jsonify({'message': 'Метод GET не поддерживается для этого маршрута'}), 405

@auth_bp.route("/register", methods = ["GET", "POST"])
def register():
    if request.method == 'POST':
        item = request.get_json()
        email = item['email']
        password = item['password']
        if request.method=="POST":
            if not ( password or email):
                return jsonify({'success': True,'message': 'Пожалуйста заполните поля'}), 201
            else:
                hash_pwd=generate_password_hash(password)
                new_user=User(password = hash_pwd, email=email)
                try:
                    db.session.add(new_user)
                    db.session.commit()
                    return jsonify({'success': True, 'message' : 'Пользователь зарегестрирован'}), 201
                except:
                    return jsonify({'success': True,'message': 'Ошибка при регистрации пользователя'}), 201
    else:
        return jsonify({'success': True,'message': 'Ошибка при отправке запроса'}), 201

@auth_bp.route('/api/logout', methods=['POST'])
@token_required
def logout(user_id):
    logout_user()
    return jsonify({'message': 'Logged out successfully'}), 200

@auth_bp.route('/token_verify', methods = ["POST"])
@token_required
def protected_route(user_id):
    return jsonify({'message': f'Protected route accessed by user {user_id}', 'valid': True})
