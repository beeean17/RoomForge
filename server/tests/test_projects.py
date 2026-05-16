from dataclasses import dataclass
from datetime import UTC, datetime

from app.auth.firebase import FirebaseIdentity, InvalidAuthToken
from app.main import create_app
from app.repositories.projects import (
    ProjectCreate,
    ProjectNotFound,
    ProjectRecord,
    ProjectUpdate,
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

    def get_for_user(self, user: UserRecord, project_id: int) -> ProjectRecord:
        self.last_user_id = user.id
        for project in self.projects:
            if project.id == project_id and project.user_id == user.id:
                return project
        raise ProjectNotFound()

    def update_for_user(
        self, user: UserRecord, project_id: int, payload: ProjectUpdate
    ) -> ProjectRecord:
        self.last_user_id = user.id
        existing = self.get_for_user(user, project_id)
        updated = ProjectRecord(
            id=existing.id,
            user_id=existing.user_id,
            name=payload.name,
            description=payload.description,
            created_at=existing.created_at,
            updated_at=datetime(2026, 5, 14, tzinfo=UTC),
        )
        self.projects = [
            updated if project.id == project_id else project for project in self.projects
        ]
        return updated

    def delete_for_user(self, user: UserRecord, project_id: int) -> None:
        self.last_user_id = user.id
        existing = self.get_for_user(user, project_id)
        self.projects = [project for project in self.projects if project.id != existing.id]


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


def test_get_project_returns_owned_project() -> None:
    from fastapi.testclient import TestClient

    app = create_app()
    app.state.token_verifier = FakeTokenVerifier()
    app.state.user_repository = FakeUserRepository()
    app.state.project_repository = FakeProjectRepository()

    response = TestClient(app).get(
        "/room-projects/1",
        headers={"Authorization": "Bearer valid-token"},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["error"] is None
    assert body["data"]["project"]["id"] == 1
    assert body["data"]["project"]["user_id"] == 42


def test_get_project_does_not_disclose_other_users_project() -> None:
    from fastapi.testclient import TestClient

    app = create_app()
    repository = FakeProjectRepository()
    repository.projects.append(
        ProjectRecord(
            id=99,
            user_id=999,
            name="Other User Project",
            description=None,
            created_at=datetime(2026, 5, 13, tzinfo=UTC),
            updated_at=datetime(2026, 5, 13, tzinfo=UTC),
        )
    )
    app.state.token_verifier = FakeTokenVerifier()
    app.state.user_repository = FakeUserRepository()
    app.state.project_repository = repository

    response = TestClient(app).get(
        "/room-projects/99",
        headers={"Authorization": "Bearer valid-token"},
    )

    assert response.status_code == 404
    body = response.json()
    assert body["data"] is None
    assert body["error"]["code"] == "not_found"


def test_update_project_persists_owned_metadata() -> None:
    from fastapi.testclient import TestClient

    app = create_app()
    app.state.token_verifier = FakeTokenVerifier()
    app.state.user_repository = FakeUserRepository()
    app.state.project_repository = FakeProjectRepository()

    response = TestClient(app).put(
        "/room-projects/1",
        headers={"Authorization": "Bearer valid-token"},
        json={"name": "Renamed Project", "description": "Updated"},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["data"]["project"]["name"] == "Renamed Project"
    assert body["data"]["project"]["description"] == "Updated"
    assert body["data"]["project"]["user_id"] == 42


def test_update_project_does_not_update_other_users_project() -> None:
    from fastapi.testclient import TestClient

    app = create_app()
    repository = FakeProjectRepository()
    repository.projects.append(
        ProjectRecord(
            id=99,
            user_id=999,
            name="Other User Project",
            description=None,
            created_at=datetime(2026, 5, 13, tzinfo=UTC),
            updated_at=datetime(2026, 5, 13, tzinfo=UTC),
        )
    )
    app.state.token_verifier = FakeTokenVerifier()
    app.state.user_repository = FakeUserRepository()
    app.state.project_repository = repository

    response = TestClient(app).put(
        "/room-projects/99",
        headers={"Authorization": "Bearer valid-token"},
        json={"name": "Illegal Rename"},
    )

    assert response.status_code == 404
    assert response.json()["data"] is None


def test_delete_project_removes_owned_project_from_active_list() -> None:
    from fastapi.testclient import TestClient

    app = create_app()
    repository = FakeProjectRepository()
    app.state.token_verifier = FakeTokenVerifier()
    app.state.user_repository = FakeUserRepository()
    app.state.project_repository = repository
    client = TestClient(app)

    response = client.delete(
        "/room-projects/1",
        headers={"Authorization": "Bearer valid-token"},
    )

    assert response.status_code == 204
    list_response = client.get(
        "/room-projects",
        headers={"Authorization": "Bearer valid-token"},
    )
    assert list_response.json()["data"]["projects"] == []


def test_delete_project_does_not_delete_other_users_project() -> None:
    from fastapi.testclient import TestClient

    app = create_app()
    repository = FakeProjectRepository()
    repository.projects.append(
        ProjectRecord(
            id=99,
            user_id=999,
            name="Other User Project",
            description=None,
            created_at=datetime(2026, 5, 13, tzinfo=UTC),
            updated_at=datetime(2026, 5, 13, tzinfo=UTC),
        )
    )
    app.state.token_verifier = FakeTokenVerifier()
    app.state.user_repository = FakeUserRepository()
    app.state.project_repository = repository

    response = TestClient(app).delete(
        "/room-projects/99",
        headers={"Authorization": "Bearer valid-token"},
    )

    assert response.status_code == 404
    assert any(project.id == 99 for project in repository.projects)
