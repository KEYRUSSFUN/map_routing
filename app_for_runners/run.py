from app import create_app
from extensions import socketio

app = create_app()


if __name__ == '__main__':
    print('Starting server on port 5000 (Flask-SocketIO)...')
    socketio.run(app, host='0.0.0.0', port=5000, debug=False)
