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
    }
    CORS_ALLOWED_ORIGINS = os.environ.get('CORS_ALLOWED_ORIGINS', '*')
