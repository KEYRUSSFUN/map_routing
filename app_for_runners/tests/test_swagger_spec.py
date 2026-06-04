def test_swagger_spec_has_key_paths(client):
    from tests.test_helpers import assert_status

    resp = client.get("/swagger.json")
    assert_status(resp, 200, "GET /swagger.json (spec)")
    spec = resp.get_json()
    assert spec["openapi"] == "3.0.3"

    paths = spec.get("paths", {})
    assert "/api/user_info" in paths
    assert "get" in paths["/api/user_info"]
    assert "post" in paths["/api/user_info"]

    assert "/api/user_statistic" in paths
    assert "get" in paths["/api/user_statistic"]
    assert "post" in paths["/api/user_statistic"]

    assert "/api/friends" in paths
    assert "get" in paths["/api/friends"]

    assert "/api/group_chats" in paths
    assert "get" in paths["/api/group_chats"]
    assert "post" in paths["/api/group_chats"]

