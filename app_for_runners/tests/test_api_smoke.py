def test_swagger_json_and_ui(client):
    resp = client.get("/swagger.json")
    from tests.test_helpers import assert_status
    assert_status(resp, 200, "GET /swagger.json")
    data = resp.get_json()
    assert isinstance(data, dict)
    assert data.get("openapi") == "3.0.3"

    resp = client.get("/docs/")
    assert_status(resp, 200, "GET /docs/")


def test_public_routes_behaviour(client):
    # /login поддерживает только POST; GET должен вернуть 405
    resp = client.get("/login")
    from tests.test_helpers import assert_status
    assert_status(resp, 405, "GET /login")

    # /register имеет GET (возвращает JSON и 201 в текущей реализации)
    resp = client.get("/register")
    assert_status(resp, 201, "GET /register")


def test_token_required_endpoints_return_401(client):
    # Эти endpoints защищены декоратором `token_required`.
    # При отсутствии Authorization-заголовка декоратор возвращает 401 ещё до работы с БД.
    protected = [
        ("/api/friends", "GET"),
        ("/api/user_info/check", "GET"),
        ("/api/user_info", "POST"),
        ("/api/user_statistic", "GET"),
        ("/api/logout", "POST"),
        ("/api/group_chats/1", "GET"),
    ]

    for url, method in protected:
        if method == "GET":
            resp = client.get(url)
        else:
            resp = client.post(url, json={})

        from tests.test_helpers import assert_status
        assert_status(resp, 401, f"{method} {url}")
        data = resp.get_json()
        assert data is not None
        assert data.get("message") == "Токен отсутствует"

