from flask import Flask, render_template, request, redirect, url_for, flash, session, jsonify
from flask_sqlalchemy import SQLAlchemy
from geoalchemy2 import Geometry
from flask_login import LoginManager, UserMixin, login_user, login_required, logout_user
from werkzeug.security import check_password_hash, generate_password_hash # для хэширования паролей
from datetime import datetime, timedelta
from flask_cors import CORS
from functools import wraps
import jwt

app=Flask(__name__)
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///kurs.db'
db=SQLAlchemy(app)

CORS(app)
#Для сессий:
app.config['SECRET_KEY']='2d75155246883f023ee10d89cfae0663e3515f9a'


class Geolocation(db.Model):
    __tablename__ = 'geolocation'  # Указываем имя таблицы, если это не 'geolocation'
    id_Geolocation = db.Column(db.Integer, primary_key=True)
    id_User = db.Column(db.Integer, db.ForeignKey('user_info.id_User'))  # Добавляем внешний ключ на UserInfo
    point1 = db.Column(Geometry(geometry_type='POINT', srid=4326))
    point2 = db.Column(Geometry(geometry_type='POINT', srid=4326))
    distance = db.Column(db.Float, nullable=False)

    # Связь с UserInfo
    user_info = db.relationship("UserInfo", back_populates="geolocations")
# Таблица зарегистрированных пользователей
class User(db.Model, UserMixin):

    __tablename__ = 'users'  # Указываем имя таблицы, если это не 'user'
    id_User = db.Column(db.Integer, primary_key=True)
    password = db.Column(db.String(255), nullable=False)
    email = db.Column(db.String(100), nullable=False)

    # Связь с UserInfo
    user_info = db.relationship("UserInfo", back_populates="user", uselist=False)
    group_chats = db.relationship('GroupChat', 
                                  secondary='user_group_chat', 
                                  backref='members')
    def get_id(self):
        return str(self.id_User)

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
    # Связь с Geolocation
    geolocations = db.relationship("Geolocation", back_populates="user_info")

class UserGroupChatAssociation(db.Model):
    __tablename__ = 'user_group_chat'
    user_id = db.Column(db.Integer, db.ForeignKey('users.id_User'), primary_key=True)
    chat_id = db.Column(db.Integer, db.ForeignKey('group_chat.id'), primary_key=True)
    joined_at = db.Column(db.DateTime, default=datetime.utcnow)

    user = db.relationship("User", backref="group_chats_association")
    chat = db.relationship("GroupChat", backref="members_association")

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

    messages = db.relationship('GroupMessage', backref='chat', lazy='dynamic')

class GroupMessage(db.Model):
    __tablename__ = 'group_message'
    id = db.Column(db.Integer, primary_key=True)
    chat_id = db.Column(db.Integer, db.ForeignKey('group_chat.id'), nullable=False)
    sender_id = db.Column(db.Integer, db.ForeignKey('users.id_User'), nullable=False)
    content = db.Column(db.Text, nullable=False)
    timestamp = db.Column(db.DateTime, default=datetime.utcnow)

    sender = db.relationship("User", backref="sent_messages")

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

    for member_id in all_member_ids:
        if User.query.get(member_id):
            db.session.add(UserGroupChatAssociation(user_id=member_id, chat_id=new_chat.id))

    db.session.commit()
    return jsonify({'message': 'Групповой чат создан', 'chat_id': new_chat.id}), 201

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

# @app.route("/logout", methods=["GET", "POST"])
# @login_required
# def logout():
#     logout_user()
#     return redirect(url_for('index'))

if (__name__)=='__main__':
    app.run(host='0.0.0.0', port=5000, debug="true")
    
with app.app_context():
    db.create_all() #debug=True лишает необходимость постоянно перезагружать сервер, то есть он сам обновляется
