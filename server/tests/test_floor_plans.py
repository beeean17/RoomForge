from dataclasses import dataclass
from datetime import UTC, datetime

from app.auth.firebase import FirebaseIdentity, InvalidAuthToken
from app.main import create_app
from app.repositories.confirmed_geometries import ConfirmedGeometryNotFound
from app.repositories.floor_plans import FloorPlanCreate, FloorPlanNotFound, FloorPlanRecord
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


class FakeFloorPlanRepository:
    def __init__(self) -> None:
        self.owned_geometries = {(42, 1, 9)}
        self.floor_plans: list[FloorPlanRecord] = []

    def create_for_project(
        self, user: UserRecord, project_id: int, payload: FloorPlanCreate
    ) -> FloorPlanRecord:
        if (user.id, project_id, payload.confirmed_geometry_id) not in self.owned_geometries:
            raise ConfirmedGeometryNotFound()
        floor_plan = FloorPlanRecord(
            id=len(self.floor_plans) + 1,
            project_id=project_id,
            user_id=user.id,
            confirmed_geometry_id=payload.confirmed_geometry_id,
            unit="meters",
            width_value=4.2,
            depth_value=3.6,
            width_deviation_ratio=0,
            depth_deviation_ratio=0,
            aspect_ratio_error=0,
            perspective_assumptions={
                "model": "mvp_rectangular_projection",
                "reference_line": payload.reference_line,
            },
            image_geometry={"coordinate_space": "image_pixels"},
            metric_geometry={
                "coordinate_space": "meters",
                "points": [
                    {"x": 0, "y": 0},
                    {"x": 4.2, "y": 0},
                    {"x": 4.2, "y": 3.6},
                    {"x": 0, "y": 3.6},
                ],
            },
            created_at=datetime(2026, 5, 19, tzinfo=UTC),
        )
        self.floor_plans.append(floor_plan)
        return floor_plan

    def get_for_project(self, user: UserRecord, project_id: int, floor_plan_id: int) -> FloorPlanRecord:
        for floor_plan in self.floor_plans:
            if (
                floor_plan.id == floor_plan_id
                and floor_plan.project_id == project_id
                and floor_plan.user_id == user.id
            ):
                return floor_plan
        raise FloorPlanNotFound()


def configured_app(repository: FakeFloorPlanRepository):
    app = create_app()
    app.state.token_verifier = FakeTokenVerifier()
    app.state.user_repository = FakeUserRepository()
    app.state.floor_plan_repository = repository
    return app


def payload():
    return {
        "confirmed_geometry_id": 9,
        "reference_line": {"from_index": 0, "to_index": 1},
        "reference_length_value": 4.2,
        "unit": "meters",
    }


def test_create_floor_plan_requires_authentication() -> None:
    from fastapi.testclient import TestClient

    response = TestClient(create_app()).post("/room-projects/1/floor-plans", json=payload())

    assert response.status_code == 401
    assert response.json()["error"]["code"] == "unauthenticated"


def test_create_floor_plan_generates_meter_space_geometry() -> None:
    from fastapi.testclient import TestClient

    response = TestClient(configured_app(FakeFloorPlanRepository())).post(
        "/room-projects/1/floor-plans",
        headers={"Authorization": "Bearer valid-token"},
        json=payload(),
    )

    assert response.status_code == 201
    floor_plan = response.json()["data"]["floor_plan"]
    assert floor_plan["unit"] == "meters"
    assert floor_plan["metric_geometry"]["coordinate_space"] == "meters"
    assert floor_plan["width_deviation_ratio"] <= 0.05
    assert floor_plan["depth_deviation_ratio"] <= 0.05
    assert floor_plan["aspect_ratio_error"] <= 0.05
    assert floor_plan["perspective_assumptions"]["model"] == "mvp_rectangular_projection"


def test_create_floor_plan_rejects_other_users_geometry() -> None:
    from fastapi.testclient import TestClient

    response = TestClient(configured_app(FakeFloorPlanRepository())).post(
        "/room-projects/99/floor-plans",
        headers={"Authorization": "Bearer valid-token"},
        json=payload(),
    )

    assert response.status_code == 404
    assert response.json()["error"]["code"] == "not_found"


def test_get_floor_plan_returns_owned_result() -> None:
    from fastapi.testclient import TestClient

    repository = FakeFloorPlanRepository()
    client = TestClient(configured_app(repository))
    create_response = client.post(
        "/room-projects/1/floor-plans",
        headers={"Authorization": "Bearer valid-token"},
        json=payload(),
    )
    floor_plan_id = create_response.json()["data"]["floor_plan"]["id"]

    response = client.get(
        f"/room-projects/1/floor-plans/{floor_plan_id}",
        headers={"Authorization": "Bearer valid-token"},
    )

    assert response.status_code == 200
    assert response.json()["data"]["floor_plan"]["id"] == floor_plan_id
