from app.main import create_app


def test_create_app_imports() -> None:
    app = create_app()
    assert app.title == "RoomForge API"
