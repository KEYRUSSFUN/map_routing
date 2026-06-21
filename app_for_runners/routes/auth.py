from flask import Blueprint, request, jsonify, session, current_app
from werkzeug.security import check_password_hash, generate_password_hash
from flask_login import login_user, logout_user
from extensions import db
from models import User, PasswordResetToken
from services import generate_jwt, verify_jwt, verify_jwt_for_refresh
from utils.auth import token_required, extract_token
from utils.google_token import GoogleTokenError, verify_google_id_token
from utils.email_service import EmailDeliveryError, is_smtp_configured, send_password_reset_email
import secrets
from datetime import datetime, timedelta, timezone

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


def _generate_reset_code():
    return f'{secrets.randbelow(1_000_000):06d}'


def _create_password_reset_token(user):
    PasswordResetToken.query.filter_by(user_id=user.id_User).delete()

    code = _generate_reset_code()
    ttl_minutes = current_app.config.get('PASSWORD_RESET_CODE_TTL_MINUTES', 15)
    token = PasswordResetToken(
        user_id=user.id_User,
        code_hash=generate_password_hash(code),
        expires_at=datetime.now(timezone.utc) + timedelta(minutes=ttl_minutes),
    )
    db.session.add(token)
    db.session.commit()
    return code


def _password_reset_success_payload(*, reset_code=None, email_sent=False):
    if email_sent:
        message = (
            'Письмо отправлено. Если код не пришёл в течение минуты, '
            'проверьте папку «Спам».'
        )
    else:
        message = (
            'Если аккаунт с таким email существует, '
            'мы отправили код для восстановления пароля.'
        )

    payload = {
        'success': True,
        'account_exists': True,
        'email_sent': email_sent,
        'message': message,
    }
    if reset_code and current_app.config.get('EXPOSE_PASSWORD_RESET_CODE'):
        payload['reset_code'] = reset_code
    return payload


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


@auth_bp.route('/forgot-password', methods=['POST'])
def forgot_password():
    data = request.get_json(silent=True) or {}
    email = _normalize_email(data.get('email'))
    if not email:
        return jsonify({'success': False, 'message': 'Укажите email'}), 400

    user = _find_user_by_email(email)
    if user is None:
        return jsonify({
            'success': False,
            'account_exists': False,
            'email_sent': False,
            'message': 'Аккаунт с таким email не найден.',
        }), 404

    if not user.password:
        return jsonify({
            'success': False,
            'account_exists': True,
            'has_password': False,
            'email_sent': False,
            'message': 'Для этого аккаунта используйте вход через Google.',
        }), 400

    reset_code = _create_password_reset_token(user)
    ttl_minutes = current_app.config.get('PASSWORD_RESET_CODE_TTL_MINUTES', 15)

    if is_smtp_configured():
        try:
            send_password_reset_email(
                to_email=user.email,
                code=reset_code,
                ttl_minutes=ttl_minutes,
            )
        except EmailDeliveryError:
            PasswordResetToken.query.filter_by(user_id=user.id_User).delete()
            db.session.commit()
            current_app.logger.exception(
                'Не удалось отправить письмо восстановления пароля на %s',
                user.email,
            )
            return jsonify({
                'success': False,
                'account_exists': True,
                'email_sent': False,
                'message': (
                    'Не удалось отправить письмо. '
                    'Проверьте настройки почты или попробуйте позже.'
                ),
            }), 503
        return jsonify(_password_reset_success_payload(email_sent=True)), 200

    if current_app.config.get('EXPOSE_PASSWORD_RESET_CODE'):
        return jsonify(
            _password_reset_success_payload(reset_code=reset_code, email_sent=False),
        ), 200

    PasswordResetToken.query.filter_by(user_id=user.id_User).delete()
    db.session.commit()
    current_app.logger.error(
        'Запрошен сброс пароля для %s, но SMTP не настроен',
        user.email,
    )
    return jsonify({
        'success': False,
        'account_exists': True,
        'email_sent': False,
        'message': (
            'Отправка писем не настроена на сервере. '
            'Добавьте SMTP_USER и SMTP_PASSWORD в .env и перезапустите backend.'
        ),
    }), 503


@auth_bp.route('/reset-password', methods=['POST'])
def reset_password():
    data = request.get_json(silent=True) or {}
    email = _normalize_email(data.get('email'))
    code = (data.get('code') or '').strip()
    password = data.get('password')

    if not email or not code or not password:
        return jsonify({
            'success': False,
            'message': 'Заполните email, код и новый пароль',
        }), 400

    if len(password) < 8:
        return jsonify({
            'success': False,
            'message': 'Пароль должен содержать минимум 8 символов',
        }), 400

    user = _find_user_by_email(email)
    if user is None or not user.password:
        return jsonify({
            'success': False,
            'message': 'Неверный код или email',
        }), 400

    token = (
        PasswordResetToken.query.filter_by(user_id=user.id_User)
        .order_by(PasswordResetToken.created_at.desc())
        .first()
    )
    if token is None or token.is_expired:
        return jsonify({
            'success': False,
            'message': 'Код истёк. Запросите новый.',
        }), 400

    if not check_password_hash(token.code_hash, code):
        return jsonify({
            'success': False,
            'message': 'Неверный код или email',
        }), 400

    user.password = generate_password_hash(password)
    PasswordResetToken.query.filter_by(user_id=user.id_User).delete()
    db.session.commit()

    return jsonify({
        'success': True,
        'message': 'Пароль успешно изменён. Теперь можно войти.',
    }), 200
