# utils/auth.py
from functools import wraps
from flask import request, jsonify
from services import verify_jwt


def _extract_token(auth_header):
    """Фронтенд шлёт JWT напрямую в Authorization (без Bearer)."""
    if not auth_header:
        return None
    token = auth_header.strip()
    if token.lower().startswith('bearer'):
        parts = token.split(None, 1)
        token = parts[1].strip() if len(parts) > 1 else ''
    return token or None


def token_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        token = _extract_token(request.headers.get('Authorization'))
        if not token:
            return jsonify({'message': 'Токен отсутствует'}), 401

        user_id = verify_jwt(token)
        if not user_id:
            return jsonify({'message': 'Токен недействителен (время истекло)'}), 401

        return f(user_id, *args, **kwargs)

    return decorated_function
