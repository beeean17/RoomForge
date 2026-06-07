from dataclasses import dataclass
from datetime import UTC, datetime
from typing import Any

from app.auth.firebase import FirebaseIdentity, InvalidAuthToken
from app.main import create_app
from app.repositories.opencv_results import (
    OpenCvResultCreate,
    OpenCvResultNotFound,
    OpenCvResultRecord,
)
from app.repositories.reconstruction_jobs import ReconstructionJobNotFound
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


class FakeOpenCvResultRepository:
    def __init__(self) -> None:
        self.owned_jobs = {(42, 1, 7)}
        self.results: list[OpenCvResultRecord] = []

    def create_for_job(
        self, user: UserRecord, project_id: int, payload: OpenCvResultCreate
    ) -> OpenCvResultRecord:
        if (user.id, project_id, payload.job_id) not in self.owned_jobs:
            raise ReconstructionJobNotFound()
        result = OpenCvResultRecord(
            id=len(self.results) + 1,
            project_id=project_id,
            user_id=user.id,
            job_id=payload.job_id,
            coordinate_space=payload.coordinate_space,
            candidate_geometry=payload.candidate_geometry,
            confidence=payload.confidence,
            algorithm=payload.algorithm,
            created_at=datetime(2026, 5, 19, tzinfo=UTC),
        )
        self.results.append(result)
        return result

    def get_for_project(
        self, user: UserRecord, project_id: int, result_id: int
    ) -> OpenCvResultRecord:
        for result in self.results:
            if result.id == result_id and result.project_id == project_id and result.user_id == user.id:
                return result
        raise OpenCvResultNotFound()


def candidate_geometry() -> dict[str, Any]:
    return {
        "image": {"width_px": 1600, "height_px": 1200},
        "candidate_sets": [
            {
                "id": "candidate-1",
                "kind": "room_boundary",
                "points": [
                    {"x": 120, "y": 240},
                    {"x": 1420, "y": 220},
                    {"x": 1480, "y": 980},
                    {"x": 180, "y": 1020},
                ],
            }
        ],
    }


def configured_app(repository: FakeOpenCvResultRepository):
    app = create_app()
    app.state.token_verifier = FakeTokenVerifier()
    app.state.user_repository = FakeUserRepository()
    app.state.opencv_result_repository = repository
    return app


def test_create_opencv_result_requires_authentication() -> None:
    from fastapi.testclient import TestClient

    response = TestClient(create_app()).post(
        "/room-projects/1/opencv-results",
        json={
            "job_id": 7,
            "coordinate_space": "image_pixels",
            "candidate_geometry": candidate_geometry(),
            "confidence": 0.72,
        },
    )

    assert response.status_code == 401
    assert response.json()["error"]["code"] == "unauthenticated"


def test_create_opencv_result_persists_image_pixel_candidates() -> None:
    from fastapi.testclient import TestClient

    response = TestClient(configured_app(FakeOpenCvResultRepository())).post(
        "/room-projects/1/opencv-results",
        headers={"Authorization": "Bearer valid-token"},
        json={
            "job_id": 7,
            "coordinate_space": "image_pixels",
            "candidate_geometry": candidate_geometry(),
            "confidence": 0.72,
        },
    )

    assert response.status_code == 201
    body = response.json()
    result = body["data"]["opencv_result"]
    assert result["coordinate_space"] == "image_pixels"
    assert result["candidate_geometry"]["candidate_sets"][0]["kind"] == "room_boundary"
    assert result["confidence"] == 0.72


def test_create_opencv_result_rejects_non_image_pixel_coordinate_space() -> None:
    from fastapi.testclient import TestClient

    response = TestClient(configured_app(FakeOpenCvResultRepository())).post(
        "/room-projects/1/opencv-results",
        headers={"Authorization": "Bearer valid-token"},
        json={
            "job_id": 7,
            "coordinate_space": "meters",
            "candidate_geometry": candidate_geometry(),
        },
    )

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "validation_error"


def test_create_opencv_result_does_not_disclose_other_users_job() -> None:
    from fastapi.testclient import TestClient

    response = TestClient(configured_app(FakeOpenCvResultRepository())).post(
        "/room-projects/99/opencv-results",
        headers={"Authorization": "Bearer valid-token"},
        json={
            "job_id": 7,
            "coordinate_space": "image_pixels",
            "candidate_geometry": candidate_geometry(),
        },
    )

    assert response.status_code == 404
    assert response.json()["error"]["code"] == "not_found"


def test_get_opencv_result_returns_owned_candidate_geometry() -> None:
    from fastapi.testclient import TestClient

    repository = FakeOpenCvResultRepository()
    client = TestClient(configured_app(repository))
    create_response = client.post(
        "/room-projects/1/opencv-results",
        headers={"Authorization": "Bearer valid-token"},
        json={
            "job_id": 7,
            "coordinate_space": "image_pixels",
            "candidate_geometry": candidate_geometry(),
        },
    )
    result_id = create_response.json()["data"]["opencv_result"]["id"]

    response = client.get(
        f"/room-projects/1/opencv-results/{result_id}",
        headers={"Authorization": "Bearer valid-token"},
    )

    assert response.status_code == 200
    assert response.json()["data"]["opencv_result"]["id"] == result_id
