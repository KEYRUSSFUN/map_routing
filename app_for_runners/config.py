import os 
from dotenv import load_dotenv

load_dotenv()


def _normalize_database_url(url):
    """Некоторые PaaS отдают postgres:// вместо postgresql://."""
    if url and url.startswith('postgres://'):
        return url.replace('postgres://', 'postgresql://', 1)
    return url


class Config:
    SECRET_KEY = os.environ.get('SECRET_KEY', '2d75155246883f023ee10d89cfae0663e3515f9a')
    SQLALCHEMY_DATABASE_URI = _normalize_database_url(
        os.environ.get(
            'DATABASE_URL',
            'postgresql+psycopg2://postgres:postgres@localhost:5433/app_for_runners',
        )
    )
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    SQLALCHEMY_ENGINE_OPTIONS = {
        'pool_pre_ping': True,
        'pool_recycle': 300,
        'pool_size': int(os.environ.get('DB_POOL_SIZE', '10')),
        'max_overflow': int(os.environ.get('DB_MAX_OVERFLOW', '20')),
    }
    LOG_LEVEL = os.environ.get('LOG_LEVEL', 'INFO').upper()
    ENABLE_SWAGGER = os.environ.get('ENABLE_SWAGGER', 'false').lower() in (
        '1',
        'true',
        'yes',
    )
    CORS_ALLOWED_ORIGINS = os.environ.get('CORS_ALLOWED_ORIGINS', '*')
    GOOGLE_CLIENT_IDS = [
        value.strip()
        for value in os.environ.get('GOOGLE_CLIENT_IDS', '').split(',')
        if value.strip()
    ]
    # Допуск при проверке exp/iat JWT (секунды). Помогает при небольшом рассинхроне часов.
    JWT_LEEWAY_SECONDS = int(os.environ.get('JWT_LEEWAY_SECONDS', '900'))
    # Сколько дней после exp ещё можно обновить токен по подписи (без повторного входа).
    JWT_REFRESH_GRACE_DAYS = int(os.environ.get('JWT_REFRESH_GRACE_DAYS', '30'))
    AVATAR_UPLOAD_FOLDER = os.path.join(
        os.path.dirname(__file__), 'static', 'uploads', 'avatars'
    )
    MAX_AVATAR_SIZE = 5 * 1024 * 1024
    ALLOWED_AVATAR_EXTENSIONS = {'png', 'jpg', 'jpeg', 'webp'}
    ROUTE_SHARE_UPLOAD_FOLDER = os.path.join(
        os.path.dirname(__file__), 'static', 'uploads', 'route_shares'
    )
    ROUTE_SHARE_PHOTO_FOLDER = os.path.join(
        os.path.dirname(__file__), 'static', 'uploads', 'route_share_photos'
    )
    MAX_ROUTE_SHARE_SIZE = 15 * 1024 * 1024
    ALLOWED_ROUTE_SHARE_EXTENSIONS = {'gpx'}
    WORKOUT_PHOTO_UPLOAD_FOLDER = os.path.join(
        os.path.dirname(__file__), 'static', 'uploads', 'workout_photos'
    )
    MAX_WORKOUT_PHOTO_SIZE = 8 * 1024 * 1024
    ALLOWED_WORKOUT_PHOTO_EXTENSIONS = {'png', 'jpg', 'jpeg', 'webp'}
    CHAT_PHOTO_UPLOAD_FOLDER = os.path.join(
        os.path.dirname(__file__), 'static', 'uploads', 'chat_photos'
    )
    STORY_UPLOAD_FOLDER = os.path.join(
        os.path.dirname(__file__), 'static', 'uploads', 'stories'
    )
    MAX_STORY_SIZE = 8 * 1024 * 1024
    ALLOWED_STORY_EXTENSIONS = {'png', 'jpg', 'jpeg', 'webp'}
    STORY_TTL_HOURS = int(os.environ.get('STORY_TTL_HOURS', '24'))
    MOMENT_UPLOAD_FOLDER = os.path.join(
        os.path.dirname(__file__), 'static', 'uploads', 'moments'
    )
    MAX_MOMENT_SIZE = 8 * 1024 * 1024
    ALLOWED_MOMENT_EXTENSIONS = {'png', 'jpg', 'jpeg', 'webp'}

    # Redis — очередь сообщений Socket.IO для нескольких инстансов API.
    # Пример: redis://redis:6379/0  (Docker) или redis://localhost:6379/0
    REDIS_URL = os.environ.get('REDIS_URL', '').strip() or None
    SOCKETIO_MESSAGE_QUEUE = REDIS_URL
    # gevent + redis pub/sub: дефолтный socket_timeout даёт TimeoutError в listen().
    SOCKETIO_REDIS_OPTIONS = {
        'socket_timeout': None,
        'socket_connect_timeout': int(os.environ.get('REDIS_CONNECT_TIMEOUT', '5')),
    }
