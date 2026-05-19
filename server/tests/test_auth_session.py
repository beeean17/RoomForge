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
    def __init__(self) -> None:
        self.mapped_identity: FirebaseIdentity | None = None

    def upsert_from_firebase(self, identity: FirebaseIdentity) -> UserRecord:
        self.mapped_identity = identity
        return UserRecord(
            id=1,
            firebase_uid=identity.firebase_uid,
            email=identity.email,
            display_name=identity.display_name,
            role="user",
        )


def test_session_maps_valid_firebase_token_to_user_record() -> None:
    from fastapi.testclient import TestClient

    app = create_app()
    repository = FakeUserRepository()
    app.state.token_verifier = FakeTokenVerifier()
    app.state.user_repository = repository

    response = TestClient(app).get(
        "/auth/session",
        headers={"Authorization": "Bearer valid-token"},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["error"] is None
    assert body["data"]["user"]["firebase_uid"] == "firebase-user-1"
    assert body["data"]["user"]["email"] == "user@example.com"
    assert repository.mapped_identity is not None
    assert repository.mapped_identity.firebase_uid == "firebase-user-1"


def test_session_rejects_missing_token_without_user_data() -> None:
    from fastapi.testclient import TestClient

    app = create_app()
    response = TestClient(app).get("/auth/session")

    assert response.status_code == 401
    body = response.json()
    assert body["data"] is None
    assert body["error"]["code"] == "unauthenticated"


def test_session_rejects_invalid_token_without_user_data() -> None:
    from fastapi.testclient import TestClient

    app = create_app()
    app.state.token_verifier = FakeTokenVerifier(should_fail=True)
    app.state.user_repository = FakeUserRepository()

    response = TestClient(app).get(
        "/auth/session",
        headers={"Authorization": "Bearer invalid-token"},
    )

    assert response.status_code == 401
    body = response.json()
    assert body["data"] is None
    assert body["error"]["code"] == "unauthenticated"
