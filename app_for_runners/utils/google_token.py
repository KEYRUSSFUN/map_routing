from google.auth.transport import requests
from google.oauth2 import id_token
from flask import current_app


class GoogleTokenError(Exception):
    pass


def verify_google_id_token(token):
    client_ids = current_app.config.get('GOOGLE_CLIENT_IDS') or []
    if not client_ids:
        raise GoogleTokenError('Google OAuth не настроен на сервере')

    last_error = None
    for client_id in client_ids:
        try:
            idinfo = id_token.verify_oauth2_token(
                token,
                requests.Request(),
                client_id,
            )
        except ValueError as exc:
            last_error = exc
            continue

        issuer = idinfo.get('iss')
        if issuer not in ('accounts.google.com', 'https://accounts.google.com'):
            raise GoogleTokenError('Некорректный issuer Google token')

        google_id = idinfo.get('sub')
        email = idinfo.get('email')
        if not google_id or not email:
            raise GoogleTokenError('В Google token отсутствуют обязательные поля')

        return {
            'google_id': google_id,
            'email': email.strip().lower(),
            'name': (idinfo.get('name') or email.split('@')[0]).strip(),
            'picture': idinfo.get('picture'),
        }

    raise GoogleTokenError(f'Недействительный Google token: {last_error}')
