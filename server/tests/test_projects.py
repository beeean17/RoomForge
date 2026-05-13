from dataclasses import dataclass
from datetime import UTC, datetime

from app.auth.firebase import FirebaseIdentity, InvalidAuthToken
from app.main import create_app
from app.repositories.projects import ProjectCreate, ProjectRecord
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


class FakeProjectRepository:
    def __init__(self) -> None:
        self.projects: list[ProjectRecord] = [
            ProjectRecord(
                id=1,
                user_id=42,
                name="Existing Project",
                description=None,
                created_at=datetime(2026, 5, 13, tzinfo=UTC),
                updated_at=datetime(2026, 5, 13, tzinfo=UTC),
            )
        ]
        self.last_user_id: int | None = None

    def list_for_user(self, user: UserRecord) -> list[ProjectRecord]:
        self.last_user_id = user.id
        return [project for project in self.projects if project.user_id == user.id]

    def create_for_user(self, user: UserRecord, payload: ProjectCreate) -> ProjectRecord:
        self.last_user_id = user.id
        project = ProjectRecord(
            id=len(self.projects) + 1,
            user_id=user.id,
            name=payload.name,
            description=payload.description,
            created_at=datetime(2026, 5, 13, tzinfo=UTC),
            updated_at=datetime(2026, 5, 13, tzinfo=UTC),
        )
        self.projects.append(project)
        return project


def test_list_projects_requires_authentication() -> None:
    from fastapi.testclient import TestClient

    response = TestClient(create_app()).get("/room-projects")

    assert response.status_code == 401
    assert response.json()["data"] is None
    assert response.json()["error"]["code"] == "unauthenticated"


def test_list_projects_returns_only_authenticated_users_projects() -> None:
    from fastapi.testclient import TestClient

    app = create_app()
    project_repository = FakeProjectRepository()
    app.state.token_verifier = FakeTokenVerifier()
    app.state.user_repository = FakeUserRepository()
    app.state.project_repository = project_repository

    response = TestClient(app).get(
        "/room-projects",
        headers={"Authorization": "Bearer valid-token"},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["error"] is None
    assert body["data"]["projects"][0]["name"] == "Existing Project"
    assert body["data"]["projects"][0]["user_id"] == 42
    assert project_repository.last_user_id == 42


def test_create_project_stores_project_for_authenticated_user() -> None:
    from fastapi.testclient import TestClient

    app = create_app()
    project_repository = FakeProjectRepository()
    app.state.token_verifier = FakeTokenVerifier()
    app.state.user_repository = FakeUserRepository()
    app.state.project_repository = project_repository

    response = TestClient(app).post(
        "/room-projects",
        headers={"Authorization": "Bearer valid-token"},
        json={"name": "New Room", "description": "Main bedroom"},
    )

    assert response.status_code == 201
    body = response.json()
    assert body["error"] is None
    assert body["data"]["project"]["name"] == "New Room"
    assert body["data"]["project"]["description"] == "Main bedroom"
    assert body["data"]["project"]["user_id"] == 42
    assert project_repository.last_user_id == 42


def test_create_project_rejects_missing_token_without_project_data() -> None:
    from fastapi.testclient import TestClient

    response = TestClient(create_app()).post(
        "/room-projects",
        json={"name": "Should Not Persist"},
    )

    assert response.status_code == 401
    body = response.json()
    assert body["data"] is None
    assert body["error"]["code"] == "unauthenticated"
