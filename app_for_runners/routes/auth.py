from flask import Blueprint, request, jsonify, session
from werkzeug.security import check_password_hash, generate_password_hash
from flask_login import login_user, logout_user
from extensions import db
from models import User
from services import generate_jwt, verify_jwt, verify_jwt_for_refresh
from utils.auth import token_required, extract_token
from utils.google_token import GoogleTokenError, verify_google_id_token

auth_bp = Blueprint('auth', __name__)


def _normalize_email(email):
    return (email or '').strip().lower()


def _find_user_by_email(email):
    normalized = _normalize_email(email)
    if not normalized:
        return None
    return User.query.filter(
        db.func.lower(db.func.trim(User.email)) == normalized
    ).first()


def _find_or_create_google_user(google_id, email, name):
    email = _normalize_email(email)
    user = User.query.filter_by(google_id=google_id).first()
    is_new_user = False

    if user is None:
        user = _find_user_by_email(email)
        if user is not None:
            if user.password:
                raise ValueError(
                    'Этот email уже зарегистрирован. Войдите с email и паролем.'
                )
            if user.google_id and user.google_id != google_id:
                raise ValueError('Email уже привязан к другому Google аккаунту')
            user.google_id = google_id
        else:
            user = User(email=email, google_id=google_id, password=None)
            db.session.add(user)
            is_new_user = True

    if not user.email:
        user.email = email

    db.session.commit()
    return user, is_new_user, name


@auth_bp.route('/login', methods=['POST'])
def login_page():
    if request.method == 'POST':
        item = request.get_json(silent=True) or {}
        email = _normalize_email(item.get('email'))
        password = item.get('password')
        if email and password:
            user = _find_user_by_email(email)
            if user and user.password and check_password_hash(user.password, password):
                login_user(user)
                session['id_User'] = user.id_User
                token = generate_jwt(user.id_User)
                return jsonify({'success': True,'message': 'Вход успешен', 'token': token}), 201
            if user and user.google_id and not user.password:
                return jsonify({
                    'success': False,
                    'message': 'Для этого аккаунта используйте вход через Google',
                }), 201
            else:
                return jsonify({'success': False,'message': 'Не удалось войти'}), 201
        else:
            return jsonify({'success': False,'message': 'Заполните поля для входа'}), 201
    return jsonify({'message': 'Метод GET не поддерживается для этого маршрута'}), 405


@auth_bp.route('/auth/google', methods=['POST'])
def google_auth():
    data = request.get_json(silent=True) or {}
    id_token_value = data.get('id_token')
    if not id_token_value:
        return jsonify({'success': False, 'message': 'id_token обязателен'}), 400

    try:
        profile = verify_google_id_token(id_token_value)
        user, is_new_user, display_name = _find_or_create_google_user(
            profile['google_id'],
            profile['email'],
            profile['name'],
        )
    except GoogleTokenError as exc:
        return jsonify({'success': False, 'message': str(exc)}), 401
    except ValueError as exc:
        return jsonify({'success': False, 'message': str(exc)}), 409

    login_user(user)
    session['id_User'] = user.id_User
    token = generate_jwt(user.id_User)
    return jsonify({
        'success': True,
        'message': 'Вход через Google успешен',
        'token': token,
        'is_new_user': is_new_user,
        'name': display_name,
        'email': profile['email'],
    }), 201

@auth_bp.route("/register", methods=["GET", "POST"])
def register():
    if request.method != 'POST':
        return jsonify({'success': False, 'message': 'Ошибка при отправке запроса'}), 405

    item = request.get_json(silent=True) or {}
    email = _normalize_email(item.get('email'))
    password = item.get('password')

    if not email or not password:
        return jsonify({'success': False, 'message': 'Пожалуйста, заполните все поля'}), 400

    existing_user = _find_user_by_email(email)
    if existing_user is not None:
        if existing_user.google_id and not existing_user.password:
            return jsonify({
                'success': False,
                'message': 'Этот email уже зарегистрирован через Google. Войдите через Google.',
            }), 409
        return jsonify({
            'success': False,
            'message': 'Пользователь с таким email уже существует',
        }), 409

    hash_pwd = generate_password_hash(password)
    new_user = User(password=hash_pwd, email=email)
    try:
        db.session.add(new_user)
        db.session.commit()
        return jsonify({'success': True, 'message': 'Пользователь зарегистрирован'}), 201
    except Exception:
        db.session.rollback()
        return jsonify({'success': False, 'message': 'Ошибка при регистрации пользователя'}), 500

@auth_bp.route('/api/logout', methods=['POST'])
@token_required
def logout(user_id):
    logout_user()
    return jsonify({'message': 'Logged out successfully'}), 200

@auth_bp.route('/token_verify', methods = ["POST"])
@token_required
def protected_route(user_id):
    return jsonify({'message': f'Protected route accessed by user {user_id}', 'valid': True})


@auth_bp.route('/token_refresh', methods=['POST'])
def refresh_token():
    token = extract_token(request.headers.get('Authorization'))
    if not token:
        return jsonify({'message': 'Токен отсутствует', 'valid': False}), 401

    user_id = verify_jwt_for_refresh(token)
    if not user_id:
        return jsonify({'message': 'Токен недействителен', 'valid': False}), 401

    user = User.query.get(user_id)
    if not user:
        return jsonify({'message': 'Пользователь не найден', 'valid': False}), 401

    new_token = generate_jwt(user.id_User)
    return jsonify({
        'message': 'Token refreshed',
        'valid': True,
        'token': new_token,
    }), 200
