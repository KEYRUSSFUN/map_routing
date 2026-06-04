import pathlib

import pytest

from app import create_app


@pytest.fixture(scope="session")
def project_root():
    return pathlib.Path(__file__).resolve().parents[1]


@pytest.fixture()
def app(tmp_path, project_root):
    """
    Создаем приложение с временной sqlite-БД.
    Это нужно, чтобы тесты не трогали реальный `kurs.db`.
    """

    db_path = tmp_path / "test.db"

    class TestConfig:
        TESTING = True
        SECRET_KEY = "test-secret-key"
        SQLALCHEMY_DATABASE_URI = f"sqlite:///{db_path}"
        SQLALCHEMY_TRACK_MODIFICATIONS = False
        CORS_ALLOWED_ORIGINS = "*"

    app = create_app(TestConfig)
    return app


@pytest.fixture()
def client(app):
    return app.test_client()

