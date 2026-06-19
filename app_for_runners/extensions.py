import logging

import socketio as python_socketio
from flask_cors import CORS
from flask_login import LoginManager
from flask_migrate import Migrate
from flask_socketio import SocketIO
from flask_sqlalchemy import SQLAlchemy

logger = logging.getLogger(__name__)

db = SQLAlchemy()
migrate = Migrate()
login_manager = LoginManager()
socketio = SocketIO(cors_allowed_origins="*")
cors = CORS()
_socketio_startup_logged = False


def init_extensions(app):
    global _socketio_startup_logged
    db.init_app(app)
    migrate.init_app(app, db)
    login_manager.init_app(app)

    socketio_options = {
        'cors_allowed_origins': app.config.get('CORS_ALLOWED_ORIGINS', '*'),
        'async_mode': 'gevent',
    }
    message_queue = app.config.get('SOCKETIO_MESSAGE_QUEUE')
    if message_queue:
        socketio_options['client_manager'] = python_socketio.RedisManager(
            message_queue,
            redis_options=app.config.get('SOCKETIO_REDIS_OPTIONS') or {},
        )

    socketio.init_app(app, **socketio_options)

    if not _socketio_startup_logged:
        if message_queue:
            logger.info('Socket.IO message queue enabled: %s', message_queue)
        else:
            logger.info(
                'Socket.IO single-instance mode (set REDIS_URL to scale horizontally)',
            )
        _socketio_startup_logged = True

    cors.init_app(
        app,
        resources={r'/*': {'origins': app.config.get('CORS_ALLOWED_ORIGINS', '*')}},
    )
    return socketio
