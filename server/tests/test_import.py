from app.main import create_app


def test_create_app_imports() -> None:
    app = create_app()
    assert app.title == "RoomForge API"


def test_cors_allows_flutter_debug_localhost_port() -> None:
    from fastapi.testclient import TestClient

    response = TestClient(create_app()).options(
        "/room-projects",
        headers={
            "Origin": "http://localhost:50128",
            "Access-Control-Request-Method": "GET",
            "Access-Control-Request-Headers": "authorization,content-type",
        },
    )

    assert response.status_code == 200
    assert response.headers["access-control-allow-origin"] == "http://localhost:50128"
