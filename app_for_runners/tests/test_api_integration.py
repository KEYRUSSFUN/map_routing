import re

from tests.test_helpers import assert_status


def _register_and_login(client, email: str, password: str) -> str:
    reg = client.post("/register", json={"email": email, "password": password})
    assert_status(reg, 201, "POST /register")

    login = client.post("/login", json={"email": email, "password": password})
    assert_status(login, 201, "POST /login")

    data = login.get_json()
    assert isinstance(data, dict)
    token = data.get("token")
    assert isinstance(token, str)
    assert len(token) > 10
    assert re.match(r"^[A-Za-z0-9\-_\.]+$", token) is not None  # basic JWT-ish shape
    return token


def test_authorized_user_info_flow(client):
    email = "test_user_flow@example.com"
    password = "secret123"
    token = _register_and_login(client, email=email, password=password)

    headers = {"Authorization": token}

    # Сначала профиль должен отсутствовать
    check = client.get("/api/user_info/check", headers=headers)
    assert_status(check, 404, "GET /api/user_info/check (before)")
    assert check.get_json() == {"filled": False}

    # Создаем/обновляем профиль
    payload = {
        "name": "Alex",
        "weight": 72.5,
        "height": 180,
        "sex": "male",
        "age": 28,
        "country": "Russia",
    }
    update = client.post("/api/user_info", json=payload, headers=headers)
    assert_status(update, 200, "POST /api/user_info (upsert)")
    assert update.get_json() == {"success": True}

    # Проверяем снова
    check2 = client.get("/api/user_info/check", headers=headers)
    assert_status(check2, 200, "GET /api/user_info/check (after)")
    assert check2.get_json() == {"filled": True}

    # Получаем профиль
    profile = client.get("/api/user_info", headers=headers)
    assert_status(profile, 200, "GET /api/user_info")
    data = profile.get_json()
    assert data["name"] == payload["name"]
    assert data["weight"] == payload["weight"]
    assert data["height"] == payload["height"]
    assert data["sex"] == payload["sex"]
    assert data["age"] == payload["age"]
    assert data["country"] == payload["country"]


def test_token_verify_and_invalid_token(client):
    token = _register_and_login(
        client, email="test_verify@example.com", password="secret123"
    )

    ok = client.post("/token_verify", headers={"Authorization": token})
    assert_status(ok, 200, "POST /token_verify (valid token)")
    data = ok.get_json()
    assert data["valid"] is True
    assert "Protected route accessed by user" in data["message"]

    bad = client.post("/token_verify", headers={"Authorization": "badtoken"})
    assert_status(bad, 401, "POST /token_verify (invalid token)")
    assert bad.get_json()["message"] == "Токен недействителен (время истекло)"

