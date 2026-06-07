from dataclasses import dataclass
from datetime import UTC, datetime

from app.auth.firebase import FirebaseIdentity, InvalidAuthToken
from app.main import create_app
from app.repositories.dimensions import (
    RoomDimensionsNotFound,
    RoomDimensionsRecord,
    RoomDimensionsUpsert,
)
from app.repositories.projects import ProjectNotFound
from app.repositories.users import UserRecord


@dataclass
class FakeTokenVerifier:
    should_fail: bool = False

    def verify_id_token(self, token: str) -> FirebaseIdentity:
        if self.should_fail or token != "valid-token":
            raise InvalidAuthToken("invalid token")
        return FirebaseIdentity(firebase_uid="firebase-user-1")


class FakeUserRepository:
    def upsert_from_firebase(self, identity: FirebaseIdentity) -> UserRecord:
        return UserRecord(
            id=42,
            firebase_uid=identity.firebase_uid,
            email="user@example.com",
            display_name="Test User",
            role="user",
        )


class FakeRoomDimensionsRepository:
    def __init__(self) -> None:
        self.records: dict[tuple[int, int], RoomDimensionsRecord] = {}
        self.project_owner_ids = {1: 42}
        self.last_payload: RoomDimensionsUpsert | None = None

    def get_for_project(self, user: UserRecord, project_id: int) -> RoomDimensionsRecord:
        record = self.records.get((user.id, project_id))
        if record is None:
            raise RoomDimensionsNotFound()
        return record

    def upsert_for_project(
        self, user: UserRecord, project_id: int, payload: RoomDimensionsUpsert
    ) -> RoomDimensionsRecord:
        if self.project_owner_ids.get(project_id) != user.id:
            raise ProjectNotFound()
        self.last_payload = payload
        record = RoomDimensionsRecord(
            project_id=project_id,
            user_id=user.id,
            width_value=payload.width_value,
            depth_value=payload.depth_value,
            height_value=payload.height_value,
            unit=payload.unit,
            height_source=payload.height_source,
            created_at=datetime(2026, 5, 19, tzinfo=UTC),
            updated_at=datetime(2026, 5, 19, tzinfo=UTC),
        )
        self.records[(user.id, project_id)] = record
        return record


def test_upsert_room_dimensions_requires_authentication() -> None:
    from fastapi.testclient import TestClient

    response = TestClient(create_app()).put(
        "/room-projects/1/dimensions",
        json={"width_value": 4.2, "depth_value": 3.6},
    )

    assert response.status_code == 401
    assert response.json()["error"]["code"] == "unauthenticated"


def test_upsert_room_dimensions_applies_default_height() -> None:
    from fastapi.testclient import TestClient

    app = create_app()
    repository = FakeRoomDimensionsRepository()
    app.state.token_verifier = FakeTokenVerifier()
    app.state.user_repository = FakeUserRepository()
    app.state.room_dimensions_repository = repository

    response = TestClient(app).put(
        "/room-projects/1/dimensions",
        headers={"Authorization": "Bearer valid-token"},
        json={"width_value": 4.2, "depth_value": 3.6},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["error"] is None
    dimensions = body["data"]["dimensions"]
    assert dimensions["width_value"] == 4.2
    assert dimensions["depth_value"] == 3.6
    assert dimensions["height_value"] == 2.4
    assert dimensions["unit"] == "meters"
    assert dimensions["height_source"] == "default"


def test_upsert_room_dimensions_saves_user_height() -> None:
    from fastapi.testclient import TestClient

    app = create_app()
    repository = FakeRoomDimensionsRepository()
    app.state.token_verifier = FakeTokenVerifier()
    app.state.user_repository = FakeUserRepository()
    app.state.room_dimensions_repository = repository

    response = TestClient(app).put(
        "/room-projects/1/dimensions",
        headers={"Authorization": "Bearer valid-token"},
        json={"width_value": 4.2, "depth_value": 3.6, "height_value": 2.7},
    )

    assert response.status_code == 200
    dimensions = response.json()["data"]["dimensions"]
    assert dimensions["height_value"] == 2.7
    assert dimensions["height_source"] == "user"


def test_upsert_room_dimensions_rejects_invalid_values() -> None:
    from fastapi.testclient import TestClient

    app = create_app()
    repository = FakeRoomDimensionsRepository()
    app.state.token_verifier = FakeTokenVerifier()
    app.state.user_repository = FakeUserRepository()
    app.state.room_dimensions_repository = repository

    response = TestClient(app).put(
        "/room-projects/1/dimensions",
        headers={"Authorization": "Bearer valid-token"},
        json={"width_value": 0, "depth_value": 3.6},
    )

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "validation_error"
    assert repository.records == {}


def test_upsert_room_dimensions_does_not_update_other_users_project() -> None:
    from fastapi.testclient import TestClient

    app = create_app()
    repository = FakeRoomDimensionsRepository()
    repository.project_owner_ids[99] = 999
    app.state.token_verifier = FakeTokenVerifier()
    app.state.user_repository = FakeUserRepository()
    app.state.room_dimensions_repository = repository

    response = TestClient(app).put(
        "/room-projects/99/dimensions",
        headers={"Authorization": "Bearer valid-token"},
        json={"width_value": 4.2, "depth_value": 3.6},
    )

    assert response.status_code == 404
    assert response.json()["error"]["code"] == "not_found"


def test_get_room_dimensions_returns_owned_record() -> None:
    from fastapi.testclient import TestClient

    app = create_app()
    repository = FakeRoomDimensionsRepository()
    app.state.token_verifier = FakeTokenVerifier()
    app.state.user_repository = FakeUserRepository()
    app.state.room_dimensions_repository = repository
    client = TestClient(app)

    client.put(
        "/room-projects/1/dimensions",
        headers={"Authorization": "Bearer valid-token"},
        json={"width_value": 4.2, "depth_value": 3.6},
    )
    response = client.get(
        "/room-projects/1/dimensions",
        headers={"Authorization": "Bearer valid-token"},
    )

    assert response.status_code == 200
    assert response.json()["data"]["dimensions"]["project_id"] == 1
