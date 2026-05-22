from dataclasses import dataclass
from datetime import UTC, datetime

from app.auth.firebase import FirebaseIdentity, InvalidAuthToken
from app.main import create_app
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
