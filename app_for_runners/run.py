import socket
import eventlet
from app import create_app

app = create_app()

if __name__ == '__main__':
    try:
        print("Starting server on port 5000...")
        sock = eventlet.listen(('', 5000))
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        eventlet.wsgi.server(sock, app)
    except Exception as e:
        print(f"Error starting server: {e}")
        import traceback
        traceback.print_exc()
        print("\nTrying Flask development server...")
        app.run(debug=True, port=5000)
