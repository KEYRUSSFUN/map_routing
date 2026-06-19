import logging

import jwt
from datetime import datetime, timedelta, timezone
from flask import current_app

logger = logging.getLogger(__name__)


def _normalize_token(token):
    if not isinstance(token, str):
        token = token.decode('utf-8')
    return token.strip()


def _jwt_leeway_seconds():
    return int(current_app.config.get('JWT_LEEWAY_SECONDS', 900))


def generate_jwt(user_id):
    payload = {
        'user_id': user_id,
        'exp': datetime.now(timezone.utc) + timedelta(days=30),
        'iat': datetime.now(timezone.utc),
    }
    token = jwt.encode(payload, current_app.config['SECRET_KEY'], algorithm='HS256')
    if isinstance(token, bytes):
        token = token.decode('utf-8')
    return token


def _decode_jwt(token, *, verify_exp=True):
    options = {
        # iat часто ломает вход при скачках системного времени на сервере.
        'verify_iat': False,
        'verify_exp': verify_exp,
    }
    return jwt.decode(
        token,
        current_app.config['SECRET_KEY'],
        algorithms=['HS256'],
        leeway=timedelta(seconds=_jwt_leeway_seconds()),
        options=options,
    )


def verify_jwt(token):
    try:
        token = _normalize_token(token)
        payload = _decode_jwt(token, verify_exp=True)
        return payload['user_id']
    except jwt.ExpiredSignatureError:
        logger.info('JWT expired')
        return None
    except jwt.InvalidTokenError as exc:
        logger.warning('Invalid JWT: %s', exc)
        return None


def verify_jwt_for_refresh(token):
    """Проверяет подпись и срок с расширенным допуском для /token_refresh."""
    try:
        token = _normalize_token(token)
        payload = _decode_jwt(token, verify_exp=False)
        user_id = payload.get('user_id')
        if user_id is None:
            return None

        exp = payload.get('exp')
        if exp is not None:
            expired_at = datetime.fromtimestamp(exp, tz=timezone.utc)
            grace_days = int(current_app.config.get('JWT_REFRESH_GRACE_DAYS', 30))
            if datetime.now(timezone.utc) - expired_at > timedelta(days=grace_days):
                return None

        return user_id
    except jwt.InvalidTokenError as exc:
        logger.warning('Invalid refresh JWT: %s', exc)
        return None
