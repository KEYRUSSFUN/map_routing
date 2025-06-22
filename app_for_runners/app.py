import socket
from flask import Flask, render_template, request, redirect, url_for, flash, session, jsonify
import flask_socketio
from flask_sqlalchemy import SQLAlchemy
from flask_login import LoginManager, UserMixin, login_user, login_required, logout_user
from werkzeug.security import check_password_hash, generate_password_hash # для хэширования паролей
from datetime import datetime, timedelta
from flask_cors import CORS
from functools import wraps
from sqlalchemy.exc import IntegrityError
import jwt
from flask_migrate import Migrate
import eventlet

app=Flask(__name__)
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///kurs.db'
db=SQLAlchemy(app)
migrate = Migrate(app, db)

CORS(app)
#Для сессий:
app.config['SECRET_KEY']='2d75155246883f023ee10d89cfae0663e3515f9a'

# Таблица зарегистрированных пользователей
class User(db.Model, UserMixin):
    __tablename__ = 'users'
    id_User = db.Column(db.Integer, primary_key=True)
    password = db.Column(db.String(255), nullable=False)
    email = db.Column(db.String(100), nullable=False)

    user_info = db.relationship("UserInfo", back_populates="user", uselist=False)
    group_chats = db.relationship('GroupChat', secondary='user_group_chat', back_populates="members")
    friendships = db.relationship(
        'Friendship',
        foreign_keys='Friendship.user_id',
        backref=db.backref('user', lazy='joined'),
        lazy='dynamic'
    )
    friend_of = db.relationship(
        'Friendship',
        foreign_keys='Friendship.friend_id',
        backref=db.backref('friend', lazy='joined'),
        lazy='dynamic'
    )

    def get_friends(self):
        # Возвращает список подтверждённых друзей
        accepted_friendships = self.friendships.filter_by(status='accepted').all()
        return [friendship.friend for friendship in accepted_friendships]

    def get_id(self):
        return int(self.id_User)

class Friendship(db.Model):
    __tablename__ = 'friendships'
    id = db.Column(db.Integer, primary_key=True, autoincrement=True)  # Добавляем уникальный id
    user_id = db.Column(db.Integer, db.ForeignKey('users.id_User'))
    friend_id = db.Column(db.Integer, db.ForeignKey('users.id_User'))
    status = db.Column(db.String(20), default='pending')  # 'pending', 'accepted', 'rejected'
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    def __repr__(self):
        return f'<Friendship {self.id}: {self.user_id} - {self.friend_id}>'

# Таблица дополнительной информации о пользователях
class UserInfo(db.Model):
    __tablename__ = 'user_info'  # Указываем имя таблицы, если это не 'userinfo'
    id_User = db.Column(db.Integer, db.ForeignKey('users.id_User'), primary_key=True)
    name = db.Column(db.String(150), nullable=False)  # Имя
    weight = db.Column(db.Float, nullable=False) # Вес
    height = db.Column(db.Float, nullable=False) # Рост
    sex = db.Column(db.String(10), nullable=False) # Пол
    Age=db.Column(db.Integer, nullable=False)
    Country = db.Column(db.String(30), nullable=False)
    # Связь с User
    user = db.relationship("User", back_populates="user_info")

class UserGroupChatAssociation(db.Model):
    __tablename__ = 'user_group_chat'
    user_id = db.Column(db.Integer, db.ForeignKey('users.id_User'), primary_key=True)
    chat_id = db.Column(db.Integer, db.ForeignKey('group_chat.id'), primary_key=True)
    joined_at = db.Column(db.DateTime, default=datetime.utcnow)

class UserStatistic(db.Model):
    __tablename__ = 'user_statistic'
    id = db.Column(db.Integer, primary_key=True)
    id_User = db.Column(db.Integer, db.ForeignKey('user_info.id_User'), nullable=False)
    calories = db.Column(db.Float, nullable=False)
    steps = db.Column(db.Integer, nullable=False)
    distance = db.Column(db.Float, nullable=False)
    date = db.Column(db.Date, nullable=False, default=datetime.utcnow)

    # связь с UserInfo
    user_info = db.relationship("UserInfo", backref="statistics")

class GroupChat(db.Model):
    __tablename__ = 'group_chat'
    id = db.Column(db.Integer, primary_key=True)
    title = db.Column(db.String(255), nullable=False)

    members = db.relationship('User', secondary='user_group_chat', back_populates="group_chats")
    messages = db.relationship('GroupMessage', backref='chat', lazy='dynamic')

class GroupMessage(db.Model):
    __tablename__ = 'group_message'
    id = db.Column(db.Integer, primary_key=True)
    chat_id = db.Column(db.Integer, db.ForeignKey('group_chat.id'), nullable=False)
    sender_id = db.Column(db.Integer, db.ForeignKey('users.id_User'), nullable=False)
    content = db.Column(db.Text, nullable=False)
    timestamp = db.Column(db.DateTime, default=datetime.utcnow)

    sender = db.relationship("User", backref="sent_messages")

with app.app_context():
    db.create_all() #debug=True лишает необходимость постоянно перезагружать сервер, то есть он сам обновляется

# @app.route('/index')
# @app.route('/')
# def index():
#     return (render_template('index.html'))

# @app.route('/about')
# def about():
#     return (render_template('about.html'))

# Настройка авторизации
manager=LoginManager(app)



@manager.user_loader
def load_user(user_id):
    return User.query.get(user_id)


# Я ДОБАВИЛ (или поменял) C 80 ПО 132 СТРОЧКИ. В login_page возвращается token в json

def generate_jwt(user_id):
        payload = {
            'user_id': user_id,
            'exp': datetime.utcnow() + timedelta(minutes=120)  # Срок действия
        }
        token = jwt.encode(payload, app.config['SECRET_KEY'], algorithm='HS256')
        return token

def verify_jwt(token):
    try:
        payload = jwt.decode(token, app.config['SECRET_KEY'], algorithms=['HS256'])
        return payload['user_id']
    except jwt.ExpiredSignatureError:
        return None 
    except jwt.InvalidTokenError:
        return None
    
@app.route('/login', methods=['POST'])
def login_page():
    if request.method == 'POST':
        item = request.get_json()
        email = item['email']
        password = item['password']
        if email and password:
            user = User.query.filter_by(email=email).first()
            if user and check_password_hash(user.password, password):
                login_user(user) 
                session['id_User'] = user.id_User
                token = generate_jwt(user.id_User)
                return jsonify({'success': True,'message': 'Вход успешен', 'token': token}), 201
            else:
                return jsonify({'success': False,'message': 'Не удалось войти'}), 201
        else:
            return jsonify({'success': False,'message': 'Заполните поля для входа'}), 201
    return jsonify({'message': 'Метод GET не поддерживается для этого маршрута'}), 405

# Это типо login_required. Декоратор прописывается @token_requires и только для авторизированных пользователей
def token_required(f):
        @wraps(f)
        def decorated_function(*args, **kwargs):
            token = request.headers.get('Authorization')
            print(f"Received token: {token}")
            if not token:
                return jsonify({'message': 'Токен отсутствует'}), 401

            user_id = verify_jwt(token)
            if not user_id:
                return jsonify({'message': 'Токен недействителен (время истекло)'}), 401

            return f(user_id, *args, **kwargs)  # Передаем user_id в функцию

        return decorated_function

# SocketIO initialization
socketio = flask_socketio.SocketIO(app, cors_allowed_origins="*")

@socketio.on('join_chat')
def handle_join_chat(data):
    print('>>> JOIN_CHAT EVENT TRIGGERED <<<')
    print(f"Data: {data}")
    auth_header = request.headers.get('Authorization')
    token = data.get('token')
    user_id = verify_jwt(token)
    if not user_id:
        return

    chat_id = data.get('chat_id')
    user = User.query.get(user_id)
    chat = GroupChat.query.get(chat_id)
    if not chat or not UserGroupChatAssociation.query.filter_by(user_id=user_id, chat_id=chat_id).first():
        return

    flask_socketio.join_room(chat_id)
    flask_socketio.emit('joined', {'message': f'User {user.email} joined chat {chat_id}'}, room=chat_id)

@socketio.on('send_message')
def handle_send_message(data):
    print('>>> SEND_MESSAGE EVENT TRIGGERED <<<')
    print(f"Data: {data}")
    auth_header = request.headers.get('Authorization')
    token = data.get('token')
    user_id = verify_jwt(token)
    if not user_id:
        return

    chat_id = data.get('chat_id')
    content = data.get('content')
    if not content:
        return

    user = User.query.get(user_id)
    chat = GroupChat.query.get(chat_id)
    if not chat or not UserGroupChatAssociation.query.filter_by(user_id=user_id, chat_id=chat_id).first():
        return

    new_message = GroupMessage(chat_id=chat_id, sender_id=user_id, content=content)
    db.session.add(new_message)
    db.session.commit()

    message_data = {
        'id': new_message.id,
        'sender': user.email,
        'content': content,
        'timestamp': new_message.timestamp.isoformat()
    }
    flask_socketio.emit('new_message', message_data, room=chat_id)


@app.route('/api/friends', methods=['GET'])
@token_required
def get_friends(user_id):
    user = User.query.get(user_id)
    if not user:
        return jsonify({'error': 'User not found'}), 404

    friends = user.get_friends()
    friend_list = [{
        'id': friend.id_User,
        'email': friend.email,
        'name': friend.user_info.name if friend.user_info else None
    } for friend in friends]

    return jsonify(friend_list), 200

@app.route('/api/friends/requests', methods=['GET'])
@token_required
def get_friend_requests(user_id):
    try:
        # Ищем запросы, где текущий пользователь (user_id) является получателем (friend_id)
        requests = Friendship.query.filter_by(friend_id=user_id, status='pending').all()
        request_list = [
            {
                'id': req.id,  # Используем уникальный идентификатор запроса (если нужен)
                'fromUserId': req.user_id,  # ID отправителя
                'fromUserName': UserInfo.query.get(req.user_id).name if UserInfo.query.get(req.user_id) else 'Неизвестный пользователь'
            } for req in requests
        ]
        return jsonify(request_list), 200
    except Exception as e:
        print(f"Error in get_friend_requests: {e}")
        return jsonify({'error': 'Internal server error', 'details': str(e)}), 500

@app.route('/api/friends/reject_request', methods=['POST'])
@token_required
def reject_friend_request(user_id):
    try:
        data = request.get_json()
        request_id = data.get('request_id')
        if not request_id:
            return jsonify({'error': 'Request ID is required'}), 400

        request = Friendship.query.get(request_id)
        if not request or request.to_user_id != user_id or request.status != 'pending':
            return jsonify({'error': 'Invalid request'}), 400

        request.status = 'rejected'
        db.session.commit()

        return jsonify({'message': 'Friend request rejected'}), 200
    except Exception as e:
        db.session.rollback()
        print(f"Error in reject_friend_request: {e}")
        return jsonify({'error': 'Internal server error', 'details': str(e)}), 500

@app.route('/api/user_info/<int:user_id>', methods=['GET'])
@token_required
def get_user_info_by_id(user_id):
    # Проверяем, авторизован ли текущий пользователь
    current_user_id = user_id
    user = User.query.get(user_id)
    if not user:
        return jsonify({'error': 'User not found'}), 404

    user_info = UserInfo.query.filter_by(id_User=user_id).first()
    if not user_info:
        return jsonify({'error': 'User info not found'}), 404

    return jsonify({
        "id": user_info.id_User,
        "name": user_info.name,
        "weight": user_info.weight,
        "height": user_info.height,
        "sex": user_info.sex,
        "age": user_info.Age,
        "country": user_info.Country,
    }), 200

@app.route('/api/users/search', methods=['GET'])
@token_required
def search_users(user_id):
    try:
        query = request.args.get('name', '')
        print(f"Search query: {query}, user_id: {user_id}")  # Логирование запроса
        if not query:
            return jsonify({'error': 'Name query parameter is required'}), 400

        # Используем безопасный запрос с учетом регистра и отладкой
        users = UserInfo.query.filter(UserInfo.name.ilike(f'%{query}%')).all()
        user_list = []
        for user in users:
            user_dict = {
                'id': user.id_User,
                'name': user.name
            }
            print(f"Found user: {user_dict}")  # Логирование найденных пользователей
            user_list.append(user_dict)

        if not user_list:
            print(f"No users found for query: {query}")  # Дополнительное логирование
        return jsonify(user_list), 200
    except Exception as e:
        print(f"Error in search_users: {e}")  # Логирование ошибки
        return jsonify({'error': 'Internal server error', 'details': str(e)}), 500

@app.route('/api/friends/send_request', methods=['POST'])
@token_required
def send_friend_request(user_id):
    data = request.get_json()
    friend_id = data.get('friend_id')

    if not friend_id or not User.query.get(friend_id):
        return jsonify({'error': 'Invalid friend ID'}), 400

    if user_id == friend_id:
        return jsonify({'error': 'Cannot send friend request to yourself'}), 400

    # Проверяем, существует ли уже запрос
    existing = Friendship.query.filter_by(user_id=user_id, friend_id=friend_id).first()
    if existing:
        return jsonify({'error': 'Friend request already sent'}), 400

    # Проверяем обратную связь (чтобы избежать дубликатов)
    reverse = Friendship.query.filter_by(user_id=friend_id, friend_id=user_id).first()
    if reverse and reverse.status == 'accepted':
        return jsonify({'error': 'Already friends'}), 400

    new_friendship = Friendship(user_id=user_id, friend_id=friend_id, status='pending')
    db.session.add(new_friendship)
    db.session.commit()

    return jsonify({'message': 'Friend request sent', 'friend_id': friend_id}), 201

@app.route('/api/friends/accept_request', methods=['POST'])
@token_required
def accept_friend_request(user_id):
    data = request.get_json()
    friend_id = data.get('friend_id')
    print(user_id)
    print(friend_id)
    if not friend_id or not User.query.get(friend_id):
        return jsonify({'error': 'Invalid friend ID'}), 400

    friendship = Friendship.query.filter_by(user_id=friend_id, friend_id=user_id, status='pending').first()
    if not friendship:
        return jsonify({'error': 'No pending friend request found'}), 404

    friendship.status = 'accepted'
    db.session.commit()

    # Создаём обратную запись для взаимности
    reverse_friendship = Friendship.query.filter_by(user_id=user_id, friend_id=friend_id).first()
    if not reverse_friendship:
        db.session.add(Friendship(user_id=user_id, friend_id=friend_id, status='accepted'))
        db.session.commit()

    return jsonify({'message': 'Friend request accepted', 'friend_id': friend_id}), 200

@app.route('/api/group_chats', methods=['GET'])
@token_required
def get_group_chats(user_id):
    user = User.query.get(user_id)
    if not user:
        return jsonify({'error': 'User not found'}), 404

    chat_data = []
    for chat in user.group_chats:
        last_message = chat.messages.order_by(GroupMessage.timestamp.desc()).first()
        chat_data.append({
            'id': chat.id,
            'title': chat.title,
            'lastMessage': last_message.content if last_message else ''
        })

    return jsonify(chat_data), 200

@app.route('/api/group_chats', methods=['POST'])
@token_required
def create_group_chat(user_id):
    data = request.get_json()
    title = data.get('title')
    member_ids = data.get('members', [])

    if not title:
        return jsonify({'error': 'Название чата обязательно'}), 400

    # Создаем чат
    new_chat = GroupChat(title=title)
    db.session.add(new_chat)
    db.session.flush()  # получим ID, не коммитим пока

    # Добавляем создателя и участников
    all_member_ids = set(member_ids)
    all_member_ids.add(user_id)  # обязательно добавить текущего пользователя

    try:
        for member_id in all_member_ids:
            if User.query.get(member_id):
                # Проверяем, существует ли запись
                existing_association = UserGroupChatAssociation.query.filter_by(
                    user_id=member_id, chat_id=new_chat.id
                ).first()
                if not existing_association:
                    db.session.add(UserGroupChatAssociation(user_id=member_id, chat_id=new_chat.id))

        db.session.commit()
        return jsonify({'message': 'Групповой чат создан', 'chat_id': new_chat.id}), 201
    except IntegrityError as e:
        db.session.rollback()
        return jsonify({'error': 'Чат с такими участниками уже существует или произошёл конфликт.'}), 409
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': 'Ошибка при создании чата'}), 500

@app.route('/api/group_chats/<int:chat_id>/join', methods=['POST'])
@token_required
def join_group_chat(user_id, chat_id):
    chat = GroupChat.query.get(chat_id)
    if not chat:
        return jsonify({'error': 'Chat not found'}), 404

    association = UserGroupChatAssociation.query.filter_by(user_id=user_id, chat_id=chat_id).first()
    if association:
        return jsonify({'message': 'Already a member'}), 200

    new_assoc = UserGroupChatAssociation(user_id=user_id, chat_id=chat_id)
    db.session.add(new_assoc)
    db.session.commit()

    return jsonify({'message': 'Joined chat successfully'}), 201

@app.route('/api/group_chats/<int:chat_id>/add_user', methods=['POST'])
@token_required
def add_user_to_chat(user_id, chat_id):
    data = request.get_json()
    new_user_id = data.get('user_id')

    if not new_user_id:
        return jsonify({'error': 'Не указан ID пользователя'}), 400

    chat = GroupChat.query.get(chat_id)
    if not chat:
        return jsonify({'error': 'Чат не найден'}), 404

    if not User.query.get(new_user_id):
        return jsonify({'error': 'Пользователь не найден'}), 404

    existing = UserGroupChatAssociation.query.filter_by(user_id=new_user_id, chat_id=chat_id).first()
    if existing:
        return jsonify({'message': 'Пользователь уже в чате'}), 200

    db.session.add(UserGroupChatAssociation(user_id=new_user_id, chat_id=chat_id))
    db.session.commit()
    return jsonify({'message': 'Пользователь добавлен в чат'}), 201

@app.route('/api/group_chats/<int:chat_id>', methods=['GET'])
@token_required
def get_group_chat_details(user_id, chat_id):
    chat = GroupChat.query.get(chat_id)
    if not chat:
        return jsonify({'error': 'Chat not found'}), 404

    # Проверяем, что пользователь входит в чат
    assoc = UserGroupChatAssociation.query.filter_by(user_id=user_id, chat_id=chat_id).first()
    if not assoc:
        return jsonify({'error': 'Access denied'}), 403

    # Получаем участников (имена)
    participants = []
    for member in chat.members:
        if member.user_info:
            participants.append(member.user_info.name)
        else:
            participants.append(f"User {member.id_User}")

    # Получаем сообщения
    messages = []
    for msg in chat.messages.order_by(GroupMessage.timestamp.asc()).all():
        sender_name = msg.sender.user_info.name if msg.sender.user_info else f"User {msg.sender.id_User}"
        messages.append({
            'id': msg.id,
            'content': msg.content,
            'sender': sender_name,
            'timestamp': msg.timestamp.isoformat()
        })

    return jsonify({
        'id': chat.id,
        'title': chat.title,
        'participants': participants,
        'messages': messages
    }), 200

@app.route('/api/user_info/check', methods=['GET'])
@token_required
def check_user_info(user_id):
    user_info = UserInfo.query.filter_by(id_User=user_id).first()
    if user_info:
        return jsonify({"filled": True}), 200
    else:
        return jsonify({"filled": False}), 404

# Получение данных профиля
@app.route('/api/user_info', methods=['GET'])
@token_required
def get_user_info(user_id):
    print(user_id)
    user_info = UserInfo.query.filter_by(id_User=user_id).first()
    if user_info:
        return jsonify({
            "id": user_info.id_User,
            "name": user_info.name,
            "weight": user_info.weight,
            "height": user_info.height,
            "sex": user_info.sex,
            "age": user_info.Age,
            "country" : user_info.Country,
        }), 200
    else:
        return jsonify({"error": "User info not found"}), 404

@app.route('/api/user_statistic', methods=['POST'])
@token_required
def add_user_statistic(user_id):
    data = request.get_json()

    required_fields = ['calories', 'steps', 'distance', 'date']
    if not all(field in data for field in required_fields):
        return jsonify({'error': 'Missing fields'}), 400

    try:
        date_obj = datetime.strptime(data['date'], '%Y-%m-%d').date()

        # Ищем существующую запись за этот день и пользователя
        existing_stat = UserStatistic.query.filter_by(id_User=user_id, date=date_obj).first()

        if existing_stat:
            # Если запись есть — суммируем значения
            existing_stat.calories += data['calories']
            existing_stat.steps += data['steps']
            existing_stat.distance += data['distance']
        else:
            # Если записи нет — создаём новую
            new_stat = UserStatistic(
                id_User=user_id,
                calories=data['calories'],
                steps=data['steps'],
                distance=data['distance'],
                date=date_obj
            )
            db.session.add(new_stat)

        db.session.commit()
        return jsonify({'success': True, 'message': 'Статистика обновлена'}), 201
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    
@app.route('/api/user_statistic', methods=['GET'])
@token_required
def get_user_statistics(user_id):
    date_str = request.args.get('date')  # опциональный параметр ?date=2025-06-14

    try:
        if date_str:
            date = datetime.strptime(date_str, '%Y-%m-%d').date()
            stats = UserStatistic.query.filter_by(id_User=user_id, date=date).all()
        else:
            stats = UserStatistic.query.filter_by(id_User=user_id).order_by(UserStatistic.date.desc()).all()

        result = [{
            'calories': s.calories,
            'steps': s.steps,
            'distance': s.distance,
            'date': s.date.strftime('%Y-%m-%d')
        } for s in stats]

        return jsonify(result), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

# Создание или обновление профиля
@app.route('/api/user_info', methods=['POST'])
@token_required
def update_user_info(user_id):
    data = request.get_json()
    if not all(k in data for k in ['name', 'weight', 'height', 'sex', 'age']):
        return jsonify({"error": "Missing fields"}), 400

    user_info = UserInfo.query.filter_by(id_User=user_id).first()
    if user_info:
        user_info.name = data['name']
        user_info.weight = data['weight']
        user_info.height = data['height']
        user_info.sex = data['sex']
        user_info.Age = data['age']
        user_info.Country = data['country']
    else:
        user_info = UserInfo(
            id_User=user_id,
            name=data['name'],
            weight=data['weight'],
            height=data['height'],
            sex=data['sex'],
            Age=data['age'],
            Country=data['country'],
        )
        db.session.add(user_info)

    db.session.commit()
    return jsonify({"success": True}), 200


@app.route('/token_verify', methods = ["POST"])
@token_required
def protected_route(user_id):
    return jsonify({'message': f'Protected route accessed by user {user_id}', 'valid': True})

@app.route("/register", methods = ["GET", "POST"])
def register():
    if request.method == 'POST':
        item = request.get_json()
        email = item['email']    
        password = item['password']
        if request.method=="POST":
            if not ( password or email):
                return jsonify({'success': True,'message': 'Пожалуйста заполните поля'}), 201
            else:
                hash_pwd=generate_password_hash(password)
                new_user=User(password = hash_pwd, email=email)
                try:
                    db.session.add(new_user)
                    db.session.commit()
                    return jsonify({'success': True, 'message' : 'Пользователь зарегестрирован'}), 201
                except:
                    return jsonify({'success': True,'message': 'Ошибка при регистрации пользователя'}), 201
    else:
        return jsonify({'success': True,'message': 'Ошибка при отправке запроса'}), 201

@app.route('/api/logout', methods=['POST'])
@token_required
def logout(user_id):
    logout_user()
    return jsonify({'message': 'Logged out successfully'}), 200

if (__name__)=='__main__':
    sock = eventlet.listen(('', 5000))
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    eventlet.wsgi.server(sock, app)

