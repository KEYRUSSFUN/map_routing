from gevent import monkey

monkey.patch_all()

from app import create_app
from extensions import socketio
import logging

logger = logging.getLogger(__name__)

app = create_app()


if __name__ == '__main__':
    logger.info('Starting server on port 5000 (Flask-SocketIO, gevent)...')
    socketio.run(app, host='0.0.0.0', port=5000, debug=False)
