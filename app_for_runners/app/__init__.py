import os

from flask import Flask

from config import Config
from extensions import db, init_extensions, login_manager
from models import User
from swagger_docs import create_swagger_blueprint

def create_app(config_class=Config):
    app = Flask(__name__)
    app.config.from_object(config_class)
    os.makedirs(app.config['AVATAR_UPLOAD_FOLDER'], exist_ok=True)
    os.makedirs(app.config['ROUTE_SHARE_UPLOAD_FOLDER'], exist_ok=True)

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

    from routes import register_blueprints
    register_blueprints(app)
    docs_bp, swaggerui_bp = create_swagger_blueprint()
    app.register_blueprint(docs_bp)
    app.register_blueprint(swaggerui_bp)

    return app
