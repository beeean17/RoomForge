from dataclasses import dataclass
from datetime import UTC, datetime

from app.auth.firebase import FirebaseIdentity, InvalidAuthToken
from app.main import create_app
from app.repositories.confirmed_geometries import (
    ConfirmedGeometryCreate,
    ConfirmedGeometryNotFound,
    ConfirmedGeometryRecord,
)
from app.repositories.opencv_results import OpenCvResultNotFound
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


class FakeConfirmedGeometryRepository:
    def __init__(self) -> None:
        self.owned_opencv_results = {(42, 1, 3)}
        self.owned_projects = {(42, 1)}
        self.geometries: list[ConfirmedGeometryRecord] = []

    def create_for_project(
        self, user: UserRecord, project_id: int, payload: ConfirmedGeometryCreate
    ) -> ConfirmedGeometryRecord:
        if payload.opencv_result_id is None:
            if (user.id, project_id) not in self.owned_projects:
                raise OpenCvResultNotFound()
        elif (user.id, project_id, payload.opencv_result_id) not in self.owned_opencv_results:
            raise OpenCvResultNotFound()
        geometry = ConfirmedGeometryRecord(
            id=len(self.geometries) + 1,
            project_id=project_id,
            user_id=user.id,
            opencv_result_id=payload.opencv_result_id,
            coordinate_space=payload.coordinate_space,
            geometry_kind=payload.geometry_kind,
            points=payload.points,
            created_at=datetime(2026, 5, 19, tzinfo=UTC),
            updated_at=datetime(2026, 5, 19, tzinfo=UTC),
        )
        self.geometries.append(geometry)
        return geometry

    def get_for_project(
        self, user: UserRecord, project_id: int, geometry_id: int
    ) -> ConfirmedGeometryRecord:
        for geometry in self.geometries:
            if (
                geometry.id == geometry_id
                and geometry.project_id == project_id
                and geometry.user_id == user.id
            ):
                return geometry
        raise ConfirmedGeometryNotFound()


def points():
    return [
        {"x": 120, "y": 240},
        {"x": 1420, "y": 220},
        {"x": 1480, "y": 980},
        {"x": 180, "y": 1020},
    ]


def configured_app(repository: FakeConfirmedGeometryRepository):
    app = create_app()
    app.state.token_verifier = FakeTokenVerifier()
    app.state.user_repository = FakeUserRepository()
    app.state.confirmed_geometry_repository = repository
    return app


def test_create_confirmed_geometry_requires_authentication() -> None:
    from fastapi.testclient import TestClient

    response = TestClient(create_app()).post(
        "/room-projects/1/confirmed-geometries",
        json={"opencv_result_id": 3, "points": points()},
    )

    assert response.status_code == 401
    assert response.json()["error"]["code"] == "unauthenticated"


def test_create_confirmed_geometry_stores_valid_room_boundary() -> None:
    from fastapi.testclient import TestClient

    response = TestClient(configured_app(FakeConfirmedGeometryRepository())).post(
        "/room-projects/1/confirmed-geometries",
        headers={"Authorization": "Bearer valid-token"},
        json={
            "opencv_result_id": 3,
            "coordinate_space": "image_pixels",
            "geometry_kind": "room_boundary",
            "points": points(),
        },
    )

    assert response.status_code == 201
    geometry = response.json()["data"]["confirmed_geometry"]
    assert geometry["coordinate_space"] == "image_pixels"
    assert geometry["geometry_kind"] == "room_boundary"
    assert len(geometry["points"]) == 4


def test_create_confirmed_geometry_rejects_fewer_than_three_points() -> None:
    from fastapi.testclient import TestClient

    response = TestClient(configured_app(FakeConfirmedGeometryRepository())).post(
        "/room-projects/1/confirmed-geometries",
        headers={"Authorization": "Bearer valid-token"},
        json={"opencv_result_id": 3, "points": points()[:2]},
    )

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "validation_error"


def test_create_confirmed_geometry_rejects_self_intersection() -> None:
    from fastapi.testclient import TestClient

    response = TestClient(configured_app(FakeConfirmedGeometryRepository())).post(
        "/room-projects/1/confirmed-geometries",
        headers={"Authorization": "Bearer valid-token"},
        json={
            "opencv_result_id": 3,
            "points": [
                {"x": 0, "y": 0},
                {"x": 10, "y": 10},
                {"x": 0, "y": 10},
                {"x": 10, "y": 0},
            ],
        },
    )

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "validation_error"


def test_create_confirmed_geometry_does_not_disclose_other_users_result() -> None:
    from fastapi.testclient import TestClient

    response = TestClient(configured_app(FakeConfirmedGeometryRepository())).post(
        "/room-projects/99/confirmed-geometries",
        headers={"Authorization": "Bearer valid-token"},
        json={"opencv_result_id": 3, "points": points()},
    )

    assert response.status_code == 404
    assert response.json()["error"]["code"] == "not_found"


def test_get_confirmed_geometry_returns_owned_geometry() -> None:
    from fastapi.testclient import TestClient

    repository = FakeConfirmedGeometryRepository()
    client = TestClient(configured_app(repository))
    create_response = client.post(
        "/room-projects/1/confirmed-geometries",
        headers={"Authorization": "Bearer valid-token"},
        json={"opencv_result_id": 3, "points": points()},
    )
    geometry_id = create_response.json()["data"]["confirmed_geometry"]["id"]

    response = client.get(
        f"/room-projects/1/confirmed-geometries/{geometry_id}",
        headers={"Authorization": "Bearer valid-token"},
    )

    assert response.status_code == 200
    assert response.json()["data"]["confirmed_geometry"]["id"] == geometry_id
