from flask import Blueprint, jsonify
from flask_swagger_ui import get_swaggerui_blueprint


def _json_content(schema_name):
    return {
        "application/json": {
            "schema": {
                "$ref": f"#/components/schemas/{schema_name}",
            }
        }
    }


def build_openapi_spec():
    return {
        "openapi": "3.0.3",
        "info": {
            "title": "App For Runners API",
            "version": "1.0.0",
            "description": "API для мобильного приложения спортивных тренировок",
        },
        "servers": [{"url": "http://localhost:5000"}],
        "components": {
            "securitySchemes": {
                "bearerAuth": {
                    "type": "http",
                    "scheme": "bearer",
                    "bearerFormat": "JWT",
                    "description": "Введите токен в формате: Bearer <ваш_токен>",
                }
            },
            "schemas": {
                "LoginRequest": {
                    "type": "object",
                    "required": ["email", "password"],
                    "properties": {
                        "email": {"type": "string", "example": "runner@example.com"},
                        "password": {"type": "string", "example": "secret123"},
                    },
                },
                "RegisterRequest": {
                    "type": "object",
                    "required": ["email", "password"],
                    "properties": {
                        "email": {"type": "string", "example": "runner@example.com"},
                        "password": {"type": "string", "example": "secret123"},
                    },
                },
                "TokenResponse": {
                    "type": "object",
                    "properties": {
                        "success": {"type": "boolean"},
                        "message": {"type": "string"},
                        "token": {"type": "string"},
                    },
                },
                "MessageResponse": {
                    "type": "object",
                    "properties": {
                        "success": {"type": "boolean"},
                        "message": {"type": "string"},
                        "valid": {"type": "boolean"},
                    },
                },
                "UserInfoRequest": {
                    "type": "object",
                    "required": ["name", "weight", "height", "sex", "age"],
                    "properties": {
                        "name": {"type": "string", "example": "Alex"},
                        "weight": {"type": "number", "example": 72.5},
                        "height": {"type": "number", "example": 180},
                        "sex": {"type": "string", "example": "male"},
                        "age": {"type": "integer", "example": 28},
                    },
                },
                "UserInfoResponse": {
                    "type": "object",
                    "properties": {
                        "id": {"type": "integer"},
                        "name": {"type": "string"},
                        "weight": {"type": "number"},
                        "height": {"type": "number"},
                        "sex": {"type": "string"},
                        "age": {"type": "integer"},
                    },
                },
                "StatisticRequest": {
                    "type": "object",
                    "required": ["calories", "steps", "distance", "date"],
                    "properties": {
                        "calories": {"type": "number", "example": 600},
                        "steps": {"type": "integer", "example": 9000},
                        "distance": {"type": "number", "example": 6.4},
                        "date": {"type": "string", "format": "date", "example": "2026-04-16"},
                    },
                },
                "StatisticItem": {
                    "type": "object",
                    "properties": {
                        "calories": {"type": "number"},
                        "steps": {"type": "integer"},
                        "distance": {"type": "number"},
                        "date": {"type": "string", "format": "date"},
                    },
                },
                "FriendRequestBody": {
                    "type": "object",
                    "required": ["friend_id"],
                    "properties": {"friend_id": {"type": "integer", "example": 2}},
                },
                "RejectRequestBody": {
                    "type": "object",
                    "required": ["request_id"],
                    "properties": {"request_id": {"type": "integer", "example": 5}},
                },
                "FriendItem": {
                    "type": "object",
                    "properties": {
                        "id": {"type": "integer"},
                        "email": {"type": "string"},
                        "name": {"type": "string", "nullable": True},
                    },
                },
                "FriendRequestItem": {
                    "type": "object",
                    "properties": {
                        "id": {"type": "integer"},
                        "fromUserId": {"type": "integer"},
                        "fromUserName": {"type": "string"},
                    },
                },
                "CreateChatRequest": {
                    "type": "object",
                    "required": ["title"],
                    "properties": {
                        "title": {"type": "string", "example": "Morning Run"},
                        "members": {
                            "type": "array",
                            "items": {"type": "integer"},
                            "example": [2, 3],
                        },
                    },
                },
                "ChatItem": {
                    "type": "object",
                    "properties": {
                        "id": {"type": "integer"},
                        "title": {"type": "string"},
                        "lastMessage": {"type": "string"},
                    },
                },
                "AddUserToChatRequest": {
                    "type": "object",
                    "required": ["user_id"],
                    "properties": {"user_id": {"type": "integer", "example": 4}},
                },
                "ChatMessageItem": {
                    "type": "object",
                    "properties": {
                        "id": {"type": "integer"},
                        "content": {"type": "string"},
                        "sender": {"type": "string"},
                        "timestamp": {"type": "string", "format": "date-time"},
                    },
                },
                "ChatDetailsResponse": {
                    "type": "object",
                    "properties": {
                        "id": {"type": "integer"},
                        "title": {"type": "string"},
                        "participants": {"type": "array", "items": {"type": "string"}},
                        "messages": {
                            "type": "array",
                            "items": {"$ref": "#/components/schemas/ChatMessageItem"},
                        },
                    },
                },
                "SearchUserItem": {
                    "type": "object",
                    "properties": {
                        "id": {"type": "integer"},
                        "name": {"type": "string"},
                    },
                },
                "RouteRequest": {
                    "type": "object",
                    "required": ["path"],
                    "properties": {
                        "path": {
                            "type": "object",
                            "description": "GeoJSON объект с маршрутом",
                            "example": {
                                "type": "LineString",
                                "coordinates": [[37.617, 55.755], [37.618, 55.756]]
                            }
                        }
                    },
                },
                "RouteItem": {
                    "type": "object",
                    "properties": {
                        "id_Route": {"type": "integer"},
                        "path": {"type": "object"},
                        "creation_date": {"type": "string", "format": "date-time"},
                    },
                },
                "GroupRequest": {
                    "type": "object",
                    "required": ["name"],
                    "properties": {
                        "name": {"type": "string", "example": "Бегуны"},
                        "description": {"type": "string", "example": "Группа для любителей бега"},
                    },
                },
                "GroupItem": {
                    "type": "object",
                    "properties": {
                        "id": {"type": "integer"},
                        "name": {"type": "string"},
                        "description": {"type": "string"},
                    },
                },
                "MessageRequest": {
                    "type": "object",
                    "required": ["text"],
                    "properties": {
                        "text": {"type": "string", "example": "Привет всем!"},
                    },
                },
                "MessageItem": {
                    "type": "object",
                    "properties": {
                        "id": {"type": "integer"},
                        "text": {"type": "string"},
                        "sender": {"type": "string"},
                        "timestamp": {"type": "string", "format": "date-time"},
                    },
                },
            },
        },
        # Глобальная security — применяется ко всем эндпоинтам
        "security": [{"bearerAuth": []}],
        "paths": {
            "/login": {
                "post": {
                    "tags": ["Auth"],
                    "summary": "Вход пользователя",
                    "description": "Авторизация с получением JWT-токена",
                    "security": [],  # Не требует токена
                    "requestBody": {"required": True, "content": _json_content("LoginRequest")},
                    "responses": {
                        "200": {"description": "Успешный вход", "content": _json_content("TokenResponse")},
                        "401": {"description": "Неверные учётные данные"},
                    },
                }
            },
            "/register": {
                "post": {
                    "tags": ["Auth"],
                    "summary": "Регистрация пользователя",
                    "security": [],  # Не требует токена
                    "requestBody": {"required": True, "content": _json_content("RegisterRequest")},
                    "responses": {
                        "200": {"description": "Регистрация успешна", "content": _json_content("MessageResponse")},
                        "400": {"description": "Ошибка регистрации"},
                    },
                }
            },
            "/api/logout": {
                "post": {
                    "tags": ["Auth"],
                    "summary": "Выход из системы",
                    "responses": {"200": {"description": "Успешный выход", "content": _json_content("MessageResponse")}},
                }
            },
            "/token_verify": {
                "post": {
                    "tags": ["Auth"],
                    "summary": "Проверка JWT-токена",
                    "responses": {"200": {"description": "Токен валиден", "content": _json_content("MessageResponse")}},
                }
            },
            "/api/user_info/check": {
                "get": {
                    "tags": ["Profile"],
                    "summary": "Проверка наличия профиля",
                    "responses": {
                        "200": {"description": "Профиль существует"},
                        "404": {"description": "Профиль не найден"},
                    },
                }
            },
            "/api/user_info": {
                "get": {
                    "tags": ["Profile"],
                    "summary": "Получение профиля пользователя",
                    "responses": {"200": {"description": "Данные профиля", "content": _json_content("UserInfoResponse")}},
                },
                "post": {
                    "tags": ["Profile"],
                    "summary": "Создание или обновление профиля",
                    "requestBody": {"required": True, "content": _json_content("UserInfoRequest")},
                    "responses": {"200": {"description": "Профиль сохранён", "content": _json_content("MessageResponse")}},
                },
            },
            "/api/user_info/{user_id}": {
                "get": {
                    "tags": ["Profile"],
                    "summary": "Получение профиля по ID пользователя",
                    "parameters": [
                        {"name": "user_id", "in": "path", "required": True, "schema": {"type": "integer"}}
                    ],
                    "responses": {
                        "200": {"description": "Данные профиля", "content": _json_content("UserInfoResponse")},
                        "404": {"description": "Пользователь или профиль не найден"},
                    },
                }
            },
            "/api/user_statistic": {
                "get": {
                    "tags": ["Statistics"],
                    "summary": "Получение статистики пользователя",
                    "parameters": [
                        {
                            "name": "date",
                            "in": "query",
                            "required": False,
                            "schema": {"type": "string", "format": "date"},
                            "description": "Фильтр по дате (YYYY-MM-DD)",
                        }
                    ],
                    "responses": {
                        "200": {
                            "description": "Список статистики",
                            "content": {
                                "application/json": {
                                    "schema": {
                                        "type": "array",
                                        "items": {"$ref": "#/components/schemas/StatisticItem"},
                                    }
                                }
                            },
                        }
                    },
                },
                "post": {
                    "tags": ["Statistics"],
                    "summary": "Добавление статистики",
                    "requestBody": {"required": True, "content": _json_content("StatisticRequest")},
                    "responses": {"200": {"description": "Статистика сохранена", "content": _json_content("MessageResponse")}},
                },
            },
            "/api/friends": {
                "get": {
                    "tags": ["Friends"],
                    "summary": "Список друзей",
                    "responses": {
                        "200": {
                            "description": "Список друзей",
                            "content": {
                                "application/json": {
                                    "schema": {
                                        "type": "array",
                                        "items": {"$ref": "#/components/schemas/FriendItem"},
                                    }
                                }
                            },
                        }
                    },
                }
            },
            "/api/friends/requests": {
                "get": {
                    "tags": ["Friends"],
                    "summary": "Запросы в друзья",
                    "responses": {
                        "200": {
                            "description": "Список входящих запросов",
                            "content": {
                                "application/json": {
                                    "schema": {
                                        "type": "array",
                                        "items": {"$ref": "#/components/schemas/FriendRequestItem"},
                                    }
                                }
                            },
                        }
                    },
                }
            },
            "/api/friends/send_request": {
                "post": {
                    "tags": ["Friends"],
                    "summary": "Отправить запрос в друзья",
                    "requestBody": {"required": True, "content": _json_content("FriendRequestBody")},
                    "responses": {"200": {"description": "Запрос отправлен", "content": _json_content("MessageResponse")}},
                }
            },
            "/api/friends/accept_request": {
                "post": {
                    "tags": ["Friends"],
                    "summary": "Принять запрос в друзья",
                    "requestBody": {"required": True, "content": _json_content("FriendRequestBody")},
                    "responses": {"200": {"description": "Запрос принят", "content": _json_content("MessageResponse")}},
                }
            },
            "/api/friends/reject_request": {
                "post": {
                    "tags": ["Friends"],
                    "summary": "Отклонить запрос в друзья",
                    "requestBody": {"required": True, "content": _json_content("RejectRequestBody")},
                    "responses": {"200": {"description": "Запрос отклонён", "content": _json_content("MessageResponse")}},
                }
            },
            "/api/users/search": {
                "get": {
                    "tags": ["Friends"],
                    "summary": "Поиск пользователей по имени",
                    "parameters": [
                        {"name": "name", "in": "query", "required": True, "schema": {"type": "string"}}
                    ],
                    "responses": {
                        "200": {
                            "description": "Результаты поиска",
                            "content": {
                                "application/json": {
                                    "schema": {
                                        "type": "array",
                                        "items": {"$ref": "#/components/schemas/SearchUserItem"},
                                    }
                                }
                            },
                        }
                    },
                }
            },
            "/api/group_chats": {
                "get": {
                    "tags": ["Chats"],
                    "summary": "Список чатов пользователя",
                    "responses": {
                        "200": {
                            "description": "Список чатов",
                            "content": {
                                "application/json": {
                                    "schema": {
                                        "type": "array",
                                        "items": {"$ref": "#/components/schemas/ChatItem"},
                                    }
                                }
                            },
                        }
                    },
                },
                "post": {
                    "tags": ["Chats"],
                    "summary": "Создать групповой чат",
                    "requestBody": {"required": True, "content": _json_content("CreateChatRequest")},
                    "responses": {"200": {"description": "Чат создан", "content": _json_content("MessageResponse")}},
                },
            },
            "/api/group_chats/{chat_id}": {
                "get": {
                    "tags": ["Chats"],
                    "summary": "Детали чата",
                    "parameters": [
                        {"name": "chat_id", "in": "path", "required": True, "schema": {"type": "integer"}}
                    ],
                    "responses": {
                        "200": {"description": "Детали чата", "content": _json_content("ChatDetailsResponse")},
                        "403": {"description": "Доступ запрещён"},
                        "404": {"description": "Чат не найден"},
                    },
                }
            },
            "/api/group_chats/{chat_id}/join": {
                "post": {
                    "tags": ["Chats"],
                    "summary": "Присоединиться к чату",
                    "parameters": [
                        {"name": "chat_id", "in": "path", "required": True, "schema": {"type": "integer"}}
                    ],
                    "responses": {"200": {"description": "Присоединение успешно", "content": _json_content("MessageResponse")}},
                }
            },
            "/api/group_chats/{chat_id}/add_user": {
                "post": {
                    "tags": ["Chats"],
                    "summary": "Добавить пользователя в чат",
                    "parameters": [
                        {"name": "chat_id", "in": "path", "required": True, "schema": {"type": "integer"}}
                    ],
                    "requestBody": {"required": True, "content": _json_content("AddUserToChatRequest")},
                    "responses": {"200": {"description": "Пользователь добавлен", "content": _json_content("MessageResponse")}},
                }
            },
            "/api/routes": {
                "get": {
                    "tags": ["Routes"],
                    "summary": "Список маршрутов пользователя",
                    "responses": {
                        "200": {
                            "description": "Список маршрутов",
                            "content": {
                                "application/json": {
                                    "schema": {
                                        "type": "array",
                                        "items": {"$ref": "#/components/schemas/RouteItem"},
                                    }
                                }
                            },
                        }
                    },
                },
                "post": {
                    "tags": ["Routes"],
                    "summary": "Создать маршрут",
                    "requestBody": {"required": True, "content": _json_content("RouteRequest")},
                    "responses": {"200": {"description": "Маршрут создан", "content": _json_content("MessageResponse")}},
                },
            },
            "/api/routes/{route_id}": {
                "delete": {
                    "tags": ["Routes"],
                    "summary": "Удалить маршрут",
                    "parameters": [
                        {"name": "route_id", "in": "path", "required": True, "schema": {"type": "integer"}}
                    ],
                    "responses": {
                        "200": {"description": "Маршрут удалён", "content": _json_content("MessageResponse")},
                        "404": {"description": "Маршрут не найден"},
                    },
                }
            },
            "/api/groups": {
                "get": {
                    "tags": ["Groups"],
                    "summary": "Список групп пользователя",
                    "responses": {
                        "200": {
                            "description": "Список групп",
                            "content": {
                                "application/json": {
                                    "schema": {
                                        "type": "array",
                                        "items": {"$ref": "#/components/schemas/GroupItem"},
                                    }
                                }
                            },
                        }
                    },
                },
                "post": {
                    "tags": ["Groups"],
                    "summary": "Создать группу",
                    "requestBody": {"required": True, "content": _json_content("GroupRequest")},
                    "responses": {"200": {"description": "Группа создана", "content": _json_content("MessageResponse")}},
                },
            },
            "/api/groups/{group_id}/join": {
                "post": {
                    "tags": ["Groups"],
                    "summary": "Присоединиться к группе",
                    "parameters": [
                        {"name": "group_id", "in": "path", "required": True, "schema": {"type": "integer"}}
                    ],
                    "responses": {"200": {"description": "Присоединение успешно", "content": _json_content("MessageResponse")}},
                }
            },
            "/api/groups/{group_id}/messages": {
                "get": {
                    "tags": ["Groups"],
                    "summary": "Сообщения группы",
                    "parameters": [
                        {"name": "group_id", "in": "path", "required": True, "schema": {"type": "integer"}}
                    ],
                    "responses": {
                        "200": {
                            "description": "Список сообщений",
                            "content": {
                                "application/json": {
                                    "schema": {
                                        "type": "array",
                                        "items": {"$ref": "#/components/schemas/MessageItem"},
                                    }
                                }
                            },
                        }
                    },
                },
                "post": {
                    "tags": ["Groups"],
                    "summary": "Отправить сообщение в группу",
                    "parameters": [
                        {"name": "group_id", "in": "path", "required": True, "schema": {"type": "integer"}}
                    ],
                    "requestBody": {"required": True, "content": _json_content("MessageRequest")},
                    "responses": {"200": {"description": "Сообщение отправлено", "content": _json_content("MessageResponse")}},
                },
            },
        },
    }


def create_swagger_blueprint():
    docs_bp = Blueprint("swagger_json", __name__)

    @docs_bp.get("/swagger.json")
    def swagger_json():
        return jsonify(build_openapi_spec())

    swaggerui_bp = get_swaggerui_blueprint(
        "/docs",
        "/swagger.json",
        config={
            "app_name": "App For Runners API",
        },
    )

    return docs_bp, swaggerui_bp