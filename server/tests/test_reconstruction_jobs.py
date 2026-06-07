from dataclasses import dataclass
from datetime import UTC, datetime

from app.auth.firebase import FirebaseIdentity, InvalidAuthToken
from app.main import create_app
from app.repositories.projects import ProjectNotFound
from app.repositories.reconstruction_jobs import (
    ReconstructionJobCreate,
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


class FakeReconstructionJobRepository:
    def __init__(self) -> None:
        self.ready_project_source_images = {(42, 1, 5)}
        self.jobs: list[ReconstructionJobRecord] = []
        self.transitions: dict[int, list[ReconstructionJobTransitionRecord]] = {}

    def create_for_project(
        self, user: UserRecord, project_id: int, payload: ReconstructionJobCreate
    ) -> ReconstructionJobRecord:
        if (user.id, project_id, payload.source_image_id) not in self.ready_project_source_images:
            raise ProjectNotFound()
        job = ReconstructionJobRecord(
            id=len(self.jobs) + 1,
            project_id=project_id,
            user_id=user.id,
            source_image_id=payload.source_image_id,
            status="created",
            provider=payload.provider,
            retry_of_job_id=payload.retry_of_job_id,
            failure_reason_code=None,
            failure_reason_message=None,
            created_at=datetime(2026, 5, 19, tzinfo=UTC),
            updated_at=datetime(2026, 5, 19, tzinfo=UTC),
        )
        transition = ReconstructionJobTransitionRecord(
            id=1,
            job_id=job.id,
            status="created",
            actor="api",
            reason_code=None,
            reason_message="Reconstruction job created.",
            created_at=datetime(2026, 5, 19, tzinfo=UTC),
        )
        self.jobs.append(job)
        self.transitions[job.id] = [transition]
        return job

    def get_for_project(
        self, user: UserRecord, project_id: int, job_id: int
    ) -> ReconstructionJobRecord:
        for job in self.jobs:
            if job.id == job_id and job.project_id == project_id and job.user_id == user.id:
                return job
        raise ReconstructionJobNotFound()

    def list_transitions_for_job(
        self, user: UserRecord, project_id: int, job_id: int
    ) -> list[ReconstructionJobTransitionRecord]:
        self.get_for_project(user, project_id, job_id)
        return self.transitions[job_id]

    def retry_for_project(
        self, user: UserRecord, project_id: int, job_id: int
    ) -> ReconstructionJobRecord:
        original = self.get_for_project(user, project_id, job_id)
        retry = ReconstructionJobRecord(
            id=len(self.jobs) + 1,
            project_id=project_id,
            user_id=user.id,
            source_image_id=original.source_image_id,
            status="retrying",
            provider=original.provider,
            retry_of_job_id=original.id,
            failure_reason_code=None,
            failure_reason_message=None,
            created_at=datetime(2026, 5, 19, tzinfo=UTC),
            updated_at=datetime(2026, 5, 19, tzinfo=UTC),
        )
        transition = ReconstructionJobTransitionRecord(
            id=2,
            job_id=retry.id,
            status="retrying",
            actor="user",
            reason_code="retry_requested",
            reason_message="User requested reconstruction retry.",
            created_at=datetime(2026, 5, 19, tzinfo=UTC),
        )
        self.jobs.append(retry)
        self.transitions[retry.id] = [transition]
        return retry


def configured_app(repository: FakeReconstructionJobRepository):
    app = create_app()
    app.state.token_verifier = FakeTokenVerifier()
    app.state.user_repository = FakeUserRepository()
    app.state.reconstruction_job_repository = repository
    return app


def test_create_reconstruction_job_requires_authentication() -> None:
    from fastapi.testclient import TestClient

    response = TestClient(create_app()).post(
        "/room-projects/1/reconstruction-jobs",
        json={"source_image_id": 5},
    )

    assert response.status_code == 401
    assert response.json()["error"]["code"] == "unauthenticated"


def test_create_reconstruction_job_for_ready_owned_project() -> None:
    from fastapi.testclient import TestClient

    response = TestClient(configured_app(FakeReconstructionJobRepository())).post(
        "/room-projects/1/reconstruction-jobs",
        headers={"Authorization": "Bearer valid-token"},
        json={"source_image_id": 5},
    )

    assert response.status_code == 201
    body = response.json()
    assert body["error"] is None
    assert body["data"]["job"]["status"] == "created"
    assert body["data"]["job"]["status_label"] == "Ready"
    assert body["data"]["job"]["terminal"] is False
    assert body["data"]["transitions"][0]["status"] == "created"
    assert body["data"]["transitions"][0]["actor"] == "api"
    assert body["meta"]["poll_after_seconds"] == 5


def test_create_reconstruction_job_rejects_cross_user_or_unready_project() -> None:
    from fastapi.testclient import TestClient

    response = TestClient(configured_app(FakeReconstructionJobRepository())).post(
        "/room-projects/99/reconstruction-jobs",
        headers={"Authorization": "Bearer valid-token"},
        json={"source_image_id": 5},
    )

    assert response.status_code == 404
    assert response.json()["error"]["code"] == "not_found"


def test_get_reconstruction_job_returns_status_and_transitions() -> None:
    from fastapi.testclient import TestClient

    repository = FakeReconstructionJobRepository()
    client = TestClient(configured_app(repository))
    create_response = client.post(
        "/room-projects/1/reconstruction-jobs",
        headers={"Authorization": "Bearer valid-token"},
        json={"source_image_id": 5},
    )
    job_id = create_response.json()["data"]["job"]["id"]

    response = client.get(
        f"/room-projects/1/reconstruction-jobs/{job_id}",
        headers={"Authorization": "Bearer valid-token"},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["data"]["job"]["id"] == job_id
    assert body["data"]["transitions"][0]["reason_message"] == "Reconstruction job created."


def test_review_required_status_uses_needs_review_label() -> None:
    from fastapi.testclient import TestClient

    repository = FakeReconstructionJobRepository()
    job = ReconstructionJobRecord(
        id=7,
        project_id=1,
        user_id=42,
        source_image_id=5,
        status="review_required",
        provider="browser-opencv",
        retry_of_job_id=None,
        failure_reason_code=None,
        failure_reason_message=None,
        created_at=datetime(2026, 5, 19, tzinfo=UTC),
        updated_at=datetime(2026, 5, 19, tzinfo=UTC),
    )
    repository.jobs.append(job)
    repository.transitions[job.id] = [
        ReconstructionJobTransitionRecord(
            id=2,
            job_id=job.id,
            status="review_required",
            actor="editor",
            reason_code="low_confidence",
            reason_message="Candidate geometry needs review.",
            created_at=datetime(2026, 5, 19, tzinfo=UTC),
        )
    ]

    response = TestClient(configured_app(repository)).get(
        "/room-projects/1/reconstruction-jobs/7",
        headers={"Authorization": "Bearer valid-token"},
    )

    assert response.status_code == 200
    assert response.json()["data"]["job"]["status"] == "review_required"
    assert response.json()["data"]["job"]["status_label"] == "Needs review"


def test_retry_reconstruction_job_links_to_original_job() -> None:
    from fastapi.testclient import TestClient

    repository = FakeReconstructionJobRepository()
    client = TestClient(configured_app(repository))
    create_response = client.post(
        "/room-projects/1/reconstruction-jobs",
        headers={"Authorization": "Bearer valid-token"},
        json={"source_image_id": 5},
    )
    original_job_id = create_response.json()["data"]["job"]["id"]

    response = client.post(
        f"/room-projects/1/reconstruction-jobs/{original_job_id}/retry",
        headers={"Authorization": "Bearer valid-token"},
    )

    assert response.status_code == 201
    retry_job = response.json()["data"]["job"]
    assert retry_job["status"] == "retrying"
    assert retry_job["retry_of_job_id"] == original_job_id
    assert response.json()["data"]["transitions"][0]["reason_code"] == "retry_requested"


def test_retry_reconstruction_job_does_not_disclose_other_users_job() -> None:
    from fastapi.testclient import TestClient

    response = TestClient(configured_app(FakeReconstructionJobRepository())).post(
        "/room-projects/99/reconstruction-jobs/1/retry",
        headers={"Authorization": "Bearer valid-token"},
    )

    assert response.status_code == 404
    assert response.json()["error"]["code"] == "not_found"
