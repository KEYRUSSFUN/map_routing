import logging
import os

from flask import Flask

from config import Config
from extensions import db, init_extensions, login_manager
from models import User
from swagger_docs import create_swagger_blueprint


def _configure_logging(app):
    level_name = app.config.get('LOG_LEVEL', 'INFO')
    level = getattr(logging, level_name, logging.INFO)
    logging.basicConfig(
        level=level,
        format='%(asctime)s %(levelname)s [%(name)s] %(message)s',
    )
    logging.getLogger('werkzeug').setLevel(logging.WARNING)


def create_app(config_class=Config):
    app = Flask(__name__)
    app.config.from_object(config_class)
    _configure_logging(app)
    os.makedirs(app.config['AVATAR_UPLOAD_FOLDER'], exist_ok=True)
    os.makedirs(app.config['ROUTE_SHARE_UPLOAD_FOLDER'], exist_ok=True)
    os.makedirs(app.config['ROUTE_SHARE_PHOTO_FOLDER'], exist_ok=True)
    os.makedirs(app.config['WORKOUT_PHOTO_UPLOAD_FOLDER'], exist_ok=True)
    os.makedirs(app.config['STORY_UPLOAD_FOLDER'], exist_ok=True)
    os.makedirs(app.config['MOMENT_UPLOAD_FOLDER'], exist_ok=True)

    socketio = init_extensions(app)

    @login_manager.user_loader
    def load_user(user_id):
        return User.query.get(user_id)

    from services import init_socket_handlers
    init_socket_handlers(socketio)

    with app.app_context():
        db_uri = app.config.get('SQLALCHEMY_DATABASE_URI', '')
        if db_uri.startswith('sqlite'):
            db.create_all()
        from routes.challenges import ensure_default_challenges
        ensure_default_challenges()

    from routes import register_blueprints
    register_blueprints(app)

    if app.config.get('ENABLE_SWAGGER'):
        docs_bp, swaggerui_bp = create_swagger_blueprint()
        app.register_blueprint(docs_bp)
        app.register_blueprint(swaggerui_bp)

    return app
