from dataclasses import dataclass
from datetime import UTC, datetime

from app.auth.firebase import FirebaseIdentity, InvalidAuthToken
from app.main import create_app
from app.repositories.confirmed_geometries import ConfirmedGeometryRecord
from app.repositories.floor_plans import FloorPlanRecord
from app.repositories.opencv_results import OpenCvResultNotFound, OpenCvResultRecord
from app.repositories.reconstruction_jobs import (
    ReconstructionJobNotFound,
    ReconstructionJobRecord,
    ReconstructionJobTransitionRecord,
)
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


class FakeReconstructionJobRepository:
    def __init__(self) -> None:
        self.jobs = [
            ReconstructionJobRecord(
                id=1,
                project_id=10,
                user_id=20,
                source_image_id=30,
                status="created",
                provider="browser-opencv",
                retry_of_job_id=None,
                failure_reason_code=None,
                failure_reason_message=None,
                created_at=datetime(2026, 5, 22, tzinfo=UTC),
                updated_at=datetime(2026, 5, 22, tzinfo=UTC),
            ),
            ReconstructionJobRecord(
                id=2,
                project_id=11,
                user_id=21,
                source_image_id=31,
                status="review_required",
                provider="browser-opencv",
                retry_of_job_id=None,
                failure_reason_code="low_confidence",
                failure_reason_message="Needs review.",
                created_at=datetime(2026, 5, 22, tzinfo=UTC),
                updated_at=datetime(2026, 5, 22, tzinfo=UTC),
            ),
            ReconstructionJobRecord(
                id=3,
                project_id=12,
                user_id=22,
                source_image_id=32,
                status="failed",
                provider="browser-opencv",
                retry_of_job_id=None,
                failure_reason_code="opencv_failed",
                failure_reason_message="OpenCV failed.",
                created_at=datetime(2026, 5, 22, tzinfo=UTC),
                updated_at=datetime(2026, 5, 22, tzinfo=UTC),
            ),
        ]
        self.transitions = {
            2: [
                ReconstructionJobTransitionRecord(
                    id=1,
                    job_id=2,
                    status="created",
                    actor="api",
                    reason_code=None,
                    reason_message="Reconstruction job created.",
                    created_at=datetime(2026, 5, 22, tzinfo=UTC),
                ),
                ReconstructionJobTransitionRecord(
                    id=2,
                    job_id=2,
                    status="review_required",
                    actor="worker",
                    reason_code="low_confidence",
                    reason_message="Needs review.",
                    created_at=datetime(2026, 5, 22, tzinfo=UTC),
                ),
            ]
        }

    def list_for_admin(
        self, status: str | None = None
    ) -> list[ReconstructionJobRecord]:
        if status is None:
            return self.jobs
        return [job for job in self.jobs if job.status == status]

    def get_for_admin(self, job_id: int) -> ReconstructionJobRecord:
        for job in self.jobs:
            if job.id == job_id:
                return job
        raise ReconstructionJobNotFound()

    def list_transitions_for_admin(
        self, job_id: int
    ) -> list[ReconstructionJobTransitionRecord]:
        self.get_for_admin(job_id)
        return self.transitions.get(job_id, [])

    def count_retries_for_admin(self, job_id: int) -> int:
        return len([job for job in self.jobs if job.retry_of_job_id == job_id])

    def retry_for_admin(self, job_id: int) -> ReconstructionJobRecord:
        original = self.get_for_admin(job_id)
        retry = ReconstructionJobRecord(
            id=4,
            project_id=original.project_id,
            user_id=original.user_id,
            source_image_id=original.source_image_id,
            status="retrying",
            provider=original.provider,
            retry_of_job_id=original.id,
            failure_reason_code=None,
            failure_reason_message=None,
            created_at=datetime(2026, 5, 22, tzinfo=UTC),
            updated_at=datetime(2026, 5, 22, tzinfo=UTC),
        )
        self.jobs.append(retry)
        self.transitions[retry.id] = [
            ReconstructionJobTransitionRecord(
                id=3,
                job_id=retry.id,
                status="retrying",
                actor="admin",
                reason_code="admin_retry_requested",
                reason_message="Admin requested reconstruction retry.",
                created_at=datetime(2026, 5, 22, tzinfo=UTC),
            )
        ]
        return retry


class FakeOpenCvResultRepository:
    def get_latest_for_admin_job(self, job_id: int) -> OpenCvResultRecord:
        if job_id != 2:
            raise OpenCvResultNotFound()
        return OpenCvResultRecord(
            id=7,
            project_id=11,
            user_id=21,
            job_id=2,
            coordinate_space="image_pixels",
            candidate_geometry={"points": [{"x": 1, "y": 2}]},
            confidence=0.72,
            algorithm="browser-opencv",
            created_at=datetime(2026, 5, 22, tzinfo=UTC),
        )


class FakeConfirmedGeometryRepository:
    def list_for_admin_opencv_result(
        self, opencv_result_id: int
    ) -> list[ConfirmedGeometryRecord]:
        return [
            ConfirmedGeometryRecord(
                id=8,
                project_id=11,
                user_id=21,
                opencv_result_id=opencv_result_id,
                coordinate_space="image_pixels",
                geometry_kind="floor_polygon",
                points=[{"x": 3, "y": 4}],
                created_at=datetime(2026, 5, 22, tzinfo=UTC),
                updated_at=datetime(2026, 5, 22, tzinfo=UTC),
            )
        ]


class FakeFloorPlanRepository:
    def list_for_admin_confirmed_geometry(
        self, confirmed_geometry_id: int
    ) -> list[FloorPlanRecord]:
        return [
            FloorPlanRecord(
                id=9,
                project_id=11,
                user_id=21,
                confirmed_geometry_id=confirmed_geometry_id,
                unit="meters",
                width_value=4.2,
                depth_value=3.6,
                width_deviation_ratio=0,
                depth_deviation_ratio=0,
                aspect_ratio_error=0,
                perspective_assumptions={"model": "mvp_rectangular_projection"},
                image_geometry={"coordinate_space": "image_pixels"},
                metric_geometry={"coordinate_space": "meters"},
                created_at=datetime(2026, 5, 22, tzinfo=UTC),
            )
        ]


def configure_artifact_repositories(app) -> None:
    app.state.opencv_result_repository = FakeOpenCvResultRepository()
    app.state.confirmed_geometry_repository = FakeConfirmedGeometryRepository()
    app.state.floor_plan_repository = FakeFloorPlanRepository()


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


def test_admin_jobs_allows_admin_to_filter_by_allowed_status() -> None:
    from fastapi.testclient import TestClient

    app = create_app()
    app.state.token_verifier = FakeTokenVerifier()
    app.state.user_repository = FakeUserRepository(role="admin")
    app.state.reconstruction_job_repository = FakeReconstructionJobRepository()

    response = TestClient(app).get(
        "/admin/jobs?status=review_required",
        headers={"Authorization": "Bearer valid-token"},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["error"] is None
    assert body["meta"]["request_id"]
    assert body["data"]["allowed_statuses"] == [
        "created",
        "uploading",
        "processing",
        "review_required",
        "succeeded",
        "failed",
        "timeout",
        "cancelled",
        "retrying",
    ]
    assert [job["status"] for job in body["data"]["jobs"]] == ["review_required"]
    assert body["data"]["jobs"][0]["status_label"] == "Needs review"


def test_admin_jobs_rejects_normal_user_with_unauthorized_envelope() -> None:
    from fastapi.testclient import TestClient

    app = create_app()
    app.state.token_verifier = FakeTokenVerifier()
    app.state.user_repository = FakeUserRepository(role="user")
    app.state.reconstruction_job_repository = FakeReconstructionJobRepository()

    response = TestClient(app).get(
        "/admin/jobs",
        headers={"Authorization": "Bearer valid-token"},
    )

    assert response.status_code == 403
    body = response.json()
    assert body["data"] is None
    assert body["error"]["code"] == "unauthorized"


def test_admin_jobs_rejects_unknown_status() -> None:
    from fastapi.testclient import TestClient

    app = create_app()
    app.state.token_verifier = FakeTokenVerifier()
    app.state.user_repository = FakeUserRepository(role="admin")
    app.state.reconstruction_job_repository = FakeReconstructionJobRepository()

    response = TestClient(app).get(
        "/admin/jobs?status=done",
        headers={"Authorization": "Bearer valid-token"},
    )

    assert response.status_code == 422
    body = response.json()
    assert body["data"] is None
    assert body["error"]["code"] == "validation_error"


def test_admin_job_detail_returns_header_retry_count_and_event_trail() -> None:
    from fastapi.testclient import TestClient

    app = create_app()
    app.state.token_verifier = FakeTokenVerifier()
    app.state.user_repository = FakeUserRepository(role="admin")
    app.state.reconstruction_job_repository = FakeReconstructionJobRepository()

    response = TestClient(app).get(
        "/admin/jobs/2",
        headers={"Authorization": "Bearer valid-token"},
    )

    assert response.status_code == 200
    body = response.json()
    job = body["data"]["job"]
    transitions = body["data"]["transitions"]
    assert body["error"] is None
    assert body["meta"]["request_id"]
    assert job["id"] == 2
    assert job["status"] == "review_required"
    assert job["status_label"] == "Needs review"
    assert job["provider"] == "browser-opencv"
    assert body["data"]["retry_count"] == 0
    assert transitions[0]["status"] == "created"
    assert transitions[0]["actor"] == "api"
    assert transitions[1]["reason_code"] == "low_confidence"
    assert transitions[1]["reason_message"] == "Needs review."


def test_admin_job_detail_rejects_normal_user() -> None:
    from fastapi.testclient import TestClient

    app = create_app()
    app.state.token_verifier = FakeTokenVerifier()
    app.state.user_repository = FakeUserRepository(role="user")
    app.state.reconstruction_job_repository = FakeReconstructionJobRepository()

    response = TestClient(app).get(
        "/admin/jobs/2",
        headers={"Authorization": "Bearer valid-token"},
    )

    assert response.status_code == 403
    assert response.json()["error"]["code"] == "unauthorized"


def test_admin_job_artifacts_separates_candidate_confirmed_and_calibration() -> None:
    from fastapi.testclient import TestClient

    app = create_app()
    app.state.token_verifier = FakeTokenVerifier()
    app.state.user_repository = FakeUserRepository(role="admin")
    app.state.reconstruction_job_repository = FakeReconstructionJobRepository()
    configure_artifact_repositories(app)

    response = TestClient(app).get(
        "/admin/jobs/2/artifacts",
        headers={"Authorization": "Bearer valid-token"},
    )

    assert response.status_code == 200
    body = response.json()
    data = body["data"]
    assert body["error"] is None
    assert data["source_image"] == {"id": 31, "access": "restricted"}
    assert data["candidate"]["coordinate_space"] == "image_pixels"
    assert data["candidate"]["geometry"] == {"points": [{"x": 1, "y": 2}]}
    assert data["candidate"]["confidence"] == 0.72
    assert data["confirmed"][0]["points"] == [{"x": 3, "y": 4}]
    assert data["confirmed"][0]["coordinate_space"] == "image_pixels"
    assert data["calibration"][0]["metric_geometry"]["coordinate_space"] == "meters"


def test_admin_job_artifacts_rejects_normal_user() -> None:
    from fastapi.testclient import TestClient

    app = create_app()
    app.state.token_verifier = FakeTokenVerifier()
    app.state.user_repository = FakeUserRepository(role="user")
    app.state.reconstruction_job_repository = FakeReconstructionJobRepository()
    configure_artifact_repositories(app)

    response = TestClient(app).get(
        "/admin/jobs/2/artifacts",
        headers={"Authorization": "Bearer valid-token"},
    )

    assert response.status_code == 403
    assert response.json()["error"]["code"] == "unauthorized"


def test_admin_retry_failed_job_creates_linked_retry_attempt() -> None:
    from fastapi.testclient import TestClient

    app = create_app()
    repository = FakeReconstructionJobRepository()
    app.state.token_verifier = FakeTokenVerifier()
    app.state.user_repository = FakeUserRepository(role="admin")
    app.state.reconstruction_job_repository = repository

    response = TestClient(app).post(
        "/admin/jobs/3/retry",
        headers={"Authorization": "Bearer valid-token"},
    )

    assert response.status_code == 201
    body = response.json()
    job = body["data"]["job"]
    transition = body["data"]["transitions"][0]
    assert body["error"] is None
    assert job["status"] == "retrying"
    assert job["retry_of_job_id"] == 3
    assert body["data"]["retry_of_job_id"] == 3
    assert transition["actor"] == "admin"
    assert transition["reason_code"] == "admin_retry_requested"
    assert repository.get_for_admin(3).status == "failed"


def test_admin_retry_explains_unavailable_for_non_failed_job() -> None:
    from fastapi.testclient import TestClient

    app = create_app()
    app.state.token_verifier = FakeTokenVerifier()
    app.state.user_repository = FakeUserRepository(role="admin")
    app.state.reconstruction_job_repository = FakeReconstructionJobRepository()

    response = TestClient(app).post(
        "/admin/jobs/1/retry",
        headers={"Authorization": "Bearer valid-token"},
    )

    assert response.status_code == 409
    body = response.json()
    assert body["data"] is None
    assert body["error"]["code"] == "retry_unavailable"
