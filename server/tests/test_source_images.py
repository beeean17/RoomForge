import base64
from dataclasses import dataclass
from datetime import UTC, datetime

from app.auth.firebase import FirebaseIdentity, InvalidAuthToken
from app.main import create_app
from app.repositories.projects import ProjectNotFound
from app.repositories.source_images import (
    SourceImageCreate,
    SourceImageNotFound,
    SourceImageRecord,
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


class FakeSourceImageRepository:
    def __init__(self) -> None:
        self.records: list[SourceImageRecord] = []
        self.project_owner_ids = {1: 42}
        self.last_payload: SourceImageCreate | None = None

    def create_for_project(
        self, user: UserRecord, project_id: int, payload: SourceImageCreate
    ) -> SourceImageRecord:
        if self.project_owner_ids.get(project_id) != user.id:
            raise ProjectNotFound()
        self.last_payload = payload
        record = SourceImageRecord(
            id=len(self.records) + 1,
            project_id=project_id,
            user_id=user.id,
            original_filename=payload.original_filename,
            stored_name=payload.stored_name,
            content_type=payload.content_type,
            byte_size=payload.byte_size,
            width_px=payload.width_px,
            height_px=payload.height_px,
            sha256_hex=payload.sha256_hex,
            retention_status=payload.retention_status,
            uploaded_at=datetime(2026, 5, 19, tzinfo=UTC),
        )
        self.records.append(record)
        return record

    def get_for_project(
        self, user: UserRecord, project_id: int, source_image_id: int
    ) -> SourceImageRecord:
        for record in self.records:
            if (
                record.id == source_image_id
                and record.project_id == project_id
                and record.user_id == user.id
            ):
                return record
        raise SourceImageNotFound()


def upload_payload(
    *,
    content_type: str = "image/jpeg",
    image_bytes: bytes = b"fake-image-bytes",
) -> dict[str, object]:
    return {
        "filename": "living-room.jpg",
        "content_type": content_type,
        "byte_size": len(image_bytes),
        "image_base64": base64.b64encode(image_bytes).decode("ascii"),
        "width_px": 1600,
        "height_px": 1200,
    }


def test_upload_source_image_requires_authentication() -> None:
    from fastapi.testclient import TestClient

    response = TestClient(create_app()).post(
        "/room-projects/1/source-images",
        json=upload_payload(),
    )

    assert response.status_code == 401
    assert response.json()["error"]["code"] == "unauthenticated"


def test_upload_source_image_rejects_unsupported_type_without_persisting() -> None:
    from fastapi.testclient import TestClient

    app = create_app()
    repository = FakeSourceImageRepository()
    app.state.token_verifier = FakeTokenVerifier()
    app.state.user_repository = FakeUserRepository()
    app.state.source_image_repository = repository

    response = TestClient(app).post(
        "/room-projects/1/source-images",
        headers={"Authorization": "Bearer valid-token"},
        json=upload_payload(content_type="image/gif"),
    )

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "validation_error"
    assert repository.records == []


def test_upload_source_image_stores_metadata_for_owned_project() -> None:
    from fastapi.testclient import TestClient

    app = create_app()
    repository = FakeSourceImageRepository()
    app.state.token_verifier = FakeTokenVerifier()
    app.state.user_repository = FakeUserRepository()
    app.state.source_image_repository = repository

    response = TestClient(app).post(
        "/room-projects/1/source-images",
        headers={"Authorization": "Bearer valid-token"},
        json=upload_payload(),
    )

    assert response.status_code == 201
    body = response.json()
    assert body["error"] is None
    source_image = body["data"]["source_image"]
    assert source_image["project_id"] == 1
    assert source_image["user_id"] == 42
    assert source_image["original_filename"] == "living-room.jpg"
    assert source_image["content_type"] == "image/jpeg"
    assert source_image["width_px"] == 1600
    assert source_image["height_px"] == 1200
    assert source_image["retention_status"] == "active"
    assert repository.last_payload is not None
    assert repository.last_payload.image_bytes == b"fake-image-bytes"


def test_upload_source_image_does_not_disclose_other_users_project() -> None:
    from fastapi.testclient import TestClient

    app = create_app()
    repository = FakeSourceImageRepository()
    repository.project_owner_ids[99] = 999
    app.state.token_verifier = FakeTokenVerifier()
    app.state.user_repository = FakeUserRepository()
    app.state.source_image_repository = repository

    response = TestClient(app).post(
        "/room-projects/99/source-images",
        headers={"Authorization": "Bearer valid-token"},
        json=upload_payload(),
    )

    assert response.status_code == 404
    assert response.json()["error"]["code"] == "not_found"
    assert repository.records == []


def test_get_source_image_metadata_does_not_disclose_other_users_image() -> None:
    from fastapi.testclient import TestClient

    app = create_app()
    repository = FakeSourceImageRepository()
    repository.records.append(
        SourceImageRecord(
            id=7,
            project_id=99,
            user_id=999,
            original_filename="other.jpg",
            stored_name="other.jpg",
            content_type="image/jpeg",
            byte_size=12,
            width_px=None,
            height_px=None,
            sha256_hex="a" * 64,
            retention_status="active",
            uploaded_at=datetime(2026, 5, 19, tzinfo=UTC),
        )
    )
    app.state.token_verifier = FakeTokenVerifier()
    app.state.user_repository = FakeUserRepository()
    app.state.source_image_repository = repository

    response = TestClient(app).get(
        "/room-projects/99/source-images/7",
        headers={"Authorization": "Bearer valid-token"},
    )

    assert response.status_code == 404
    assert response.json()["error"]["code"] == "not_found"
