from dataclasses import dataclass
from datetime import UTC, datetime

from app.auth.firebase import FirebaseIdentity, InvalidAuthToken
from app.main import create_app
from app.repositories.layouts import LayoutRecord, LayoutSave
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


class FakeLayoutRepository:
    def __init__(self) -> None:
        self.owned_projects = {(42, 1)}
        self.saved: list[LayoutRecord] = []

    def save_for_project(self, user: UserRecord, project_id: int, payload: LayoutSave) -> LayoutRecord:
        if (user.id, project_id) not in self.owned_projects:
            raise ProjectNotFound()
        record = LayoutRecord(
            id=len(self.saved) + 1,
            project_id=project_id,
            user_id=user.id,
            room_dimensions=payload.room_dimensions,
            floor_plan=payload.floor_plan,
            source_metadata=payload.source_metadata,
            furniture_objects=payload.furniture_objects,
            editor_scene=payload.editor_scene,
            created_at=datetime(2026, 5, 22, tzinfo=UTC),
            updated_at=datetime(2026, 5, 22, tzinfo=UTC),
        )
        self.saved.append(record)
        return record


def configured_app(repository: FakeLayoutRepository):
    app = create_app()
    app.state.token_verifier = FakeTokenVerifier()
    app.state.user_repository = FakeUserRepository()
    app.state.layout_repository = repository
    return app


def layout_payload():
    return {
        "room_dimensions": {
            "unit": "meters",
            "width_value": 4.2,
            "depth_value": 3.6,
            "height_value": 2.7,
        },
        "floor_plan": {
            "coordinate_space": "meters",
            "points": [
                {"x": 0, "y": 0},
                {"x": 4.2, "y": 0},
                {"x": 4.2, "y": 3.6},
                {"x": 0, "y": 3.6},
            ],
        },
        "source_metadata": {"source_image_id": 7, "reconstruction_job_id": 9},
        "furniture_objects": [
            {
                "id": "furniture-chair-1",
                "category": "chair",
                "position": {"x": 1.2, "y": 1.4},
                "size": {
                    "width_meters": 0.55,
                    "depth_meters": 0.55,
                    "height_meters": 0.85,
                },
                "rotation_degrees": 15,
                "color": "#64748b",
            }
        ],
        "editor_scene": {"scene_id": "scene-1"},
    }


def test_save_layout_requires_authentication() -> None:
    from fastapi.testclient import TestClient

    response = TestClient(create_app()).post("/room-projects/1/layouts", json=layout_payload())

    assert response.status_code == 401
    assert response.json()["error"]["code"] == "unauthenticated"


def test_save_layout_persists_room_floor_source_and_furniture_state() -> None:
    from fastapi.testclient import TestClient

    repository = FakeLayoutRepository()
    response = TestClient(configured_app(repository)).post(
        "/room-projects/1/layouts",
        headers={"Authorization": "Bearer valid-token"},
        json=layout_payload(),
    )

    assert response.status_code == 201
    body = response.json()
    layout = body["data"]["layout"]
    furniture = layout["furniture_objects"][0]
    assert body["error"] is None
    assert body["meta"]["request_id"]
    assert layout["room_dimensions"]["unit"] == "meters"
    assert layout["floor_plan"]["coordinate_space"] == "meters"
    assert layout["source_metadata"]["source_image_id"] == 7
    assert furniture["id"] == "furniture-chair-1"
    assert furniture["category"] == "chair"
    assert furniture["position"] == {"x": 1.2, "y": 1.4}
    assert furniture["size"]["width_meters"] == 0.55
    assert furniture["rotation_degrees"] == 15
    assert furniture["color"] == "#64748b"
    assert repository.saved[0].user_id == 42


def test_save_layout_rejects_cross_user_project() -> None:
    from fastapi.testclient import TestClient

    response = TestClient(configured_app(FakeLayoutRepository())).post(
        "/room-projects/99/layouts",
        headers={"Authorization": "Bearer valid-token"},
        json=layout_payload(),
    )

    assert response.status_code == 404
    assert response.json()["error"]["code"] == "not_found"
