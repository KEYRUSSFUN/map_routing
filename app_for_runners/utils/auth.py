# utils/auth.py
from functools import wraps
from flask import request, jsonify
from services import verify_jwt

def token_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        auth_header = request.headers.get('Authorization', '')
        
        # Проверяем, что заголовок существует и начинается с Bearer
        if not auth_header or not auth_header.startswith('Bearer '):
            return jsonify({'message': 'Токен отсутствует или неверный формат'}), 401
        
        # Извлекаем токен (убираем 'Bearer ')
        token = auth_header.split(' ')[1]
        
        # Проверяем, что токен не пустой
        if not token:
            return jsonify({'message': 'Токен отсутствует'}), 401
        
        # Верифицируем токен
        user_id = verify_jwt(token)
        
        if not user_id:
            return jsonify({'message': 'Токен недействителен'}), 401
        
        return f(user_id, *args, **kwargs)
    
    return decorated_function