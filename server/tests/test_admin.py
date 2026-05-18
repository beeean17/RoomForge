from dataclasses import dataclass

from app.auth.firebase import FirebaseIdentity, InvalidAuthToken
from app.main import create_app
from app.repositories.users import UserRecord


@dataclass
class FakeTokenVerifier:
    should_fail: bool = False

    def verify_id_token(self, token: str) -> FirebaseIdentity:
        if self.should_fail or token != "valid-token":
            raise InvalidAuthToken("invalid token")
        return FirebaseIdentity(
            firebase_uid="firebase-user-1",
            email="user@example.com",
            display_name="Test User",
        )


class FakeUserRepository:
    def __init__(self, role: str) -> None:
        self._role = role

    def upsert_from_firebase(self, identity: FirebaseIdentity) -> UserRecord:
        return UserRecord(
            id=1,
            firebase_uid=identity.firebase_uid,
            email=identity.email,
            display_name=identity.display_name,
            role=self._role,
        )


def test_admin_session_requires_authentication() -> None:
    from fastapi.testclient import TestClient

    response = TestClient(create_app()).get("/admin/session")

    assert response.status_code == 401
    body = response.json()
    assert body["data"] is None
    assert body["error"]["code"] == "unauthenticated"


def test_admin_session_rejects_normal_user_with_unauthorized_envelope() -> None:
    from fastapi.testclient import TestClient

    app = create_app()
    app.state.token_verifier = FakeTokenVerifier()
    app.state.user_repository = FakeUserRepository(role="user")

    response = TestClient(app).get(
        "/admin/session",
        headers={"Authorization": "Bearer valid-token"},
    )

    assert response.status_code == 403
    body = response.json()
    assert body["data"] is None
    assert body["error"]["code"] == "unauthorized"


def test_admin_session_allows_admin_user() -> None:
    from fastapi.testclient import TestClient

    app = create_app()
    app.state.token_verifier = FakeTokenVerifier()
    app.state.user_repository = FakeUserRepository(role="admin")

    response = TestClient(app).get(
        "/admin/session",
        headers={"Authorization": "Bearer valid-token"},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["error"] is None
    assert body["data"]["admin"]["role"] == "admin"
    assert body["data"]["admin"]["firebase_uid"] == "firebase-user-1"
    assert body["data"]["capabilities"] == []
