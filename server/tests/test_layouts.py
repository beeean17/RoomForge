from dataclasses import dataclass
from datetime import UTC, datetime
from math import ceil
from time import perf_counter

from app.auth.firebase import FirebaseIdentity, InvalidAuthToken
from app.main import create_app
from app.repositories.layouts import LayoutNotFound, LayoutRecord, LayoutSave
from app.repositories.projects import ProjectNotFound, ProjectRecord
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
        self.projects = [
            ProjectRecord(
                id=1,
                user_id=42,
                name="Existing Project",
                description=None,
                created_at=datetime(2026, 5, 22, tzinfo=UTC),
                updated_at=datetime(2026, 5, 22, tzinfo=UTC),
            )
        ]

    def list_for_user(self, user: UserRecord) -> list[ProjectRecord]:
        return [project for project in self.projects if project.user_id == user.id]

    def get_for_user(self, user: UserRecord, project_id: int) -> ProjectRecord:
        for project in self.projects:
            if project.id == project_id and project.user_id == user.id:
                return project
        raise ProjectNotFound()


class FakeLayoutRepository:
    def __init__(self) -> None:
        self.owned_projects = {(42, 1)}
        self.saved: list[LayoutRecord] = []

    def save_for_project(
        self, user: UserRecord, project_id: int, payload: LayoutSave
    ) -> LayoutRecord:
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

    def get_for_project(
        self, user: UserRecord, project_id: int, layout_id: int
    ) -> LayoutRecord:
        if (user.id, project_id) not in self.owned_projects:
            raise ProjectNotFound()
        for record in self.saved:
            if (
                record.id == layout_id
                and record.project_id == project_id
                and record.user_id == user.id
            ):
                return record
        raise LayoutNotFound()

    def get_latest_for_project(
        self, user: UserRecord, project_id: int
    ) -> LayoutRecord:
        if (user.id, project_id) not in self.owned_projects:
            raise ProjectNotFound()
        records = [
            record
            for record in self.saved
            if record.project_id == project_id and record.user_id == user.id
        ]
        if not records:
            raise LayoutNotFound()
        return records[-1]


def configured_app(
    repository: FakeLayoutRepository,
    project_repository: FakeProjectRepository | None = None,
):
    app = create_app()
    app.state.token_verifier = FakeTokenVerifier()
    app.state.user_repository = FakeUserRepository()
    app.state.layout_repository = repository
    if project_repository is not None:
        app.state.project_repository = project_repository
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


def save_record(repository: FakeLayoutRepository) -> LayoutRecord:
    return repository.save_for_project(
        UserRecord(
            id=42,
            firebase_uid="firebase-user-1",
            email="user@example.com",
            display_name="Test User",
            role="user",
        ),
        1,
        LayoutSave(**layout_payload()),
    )


def required_layout_fields(layout: dict) -> dict:
    return {
        "room_dimensions": layout["room_dimensions"],
        "floor_plan": layout["floor_plan"],
        "source_metadata": layout["source_metadata"],
        "furniture_objects": layout["furniture_objects"],
        "editor_scene": layout["editor_scene"],
    }


def p95_seconds(durations: list[float]) -> float:
    ordered = sorted(durations)
    return ordered[max(ceil(len(ordered) * 0.95) - 1, 0)]


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


def test_load_latest_layout_returns_saved_state() -> None:
    from fastapi.testclient import TestClient

    repository = FakeLayoutRepository()
    save_record(repository)

    response = TestClient(configured_app(repository)).get(
        "/room-projects/1/layouts/latest",
        headers={"Authorization": "Bearer valid-token"},
    )

    assert response.status_code == 200
    body = response.json()
    layout = body["data"]["layout"]
    furniture = layout["furniture_objects"][0]
    assert body["error"] is None
    assert body["meta"]["request_id"]
    assert layout["room_dimensions"]["width_value"] == 4.2
    assert layout["floor_plan"]["coordinate_space"] == "meters"
    assert layout["source_metadata"]["reconstruction_job_id"] == 9
    assert furniture["id"] == "furniture-chair-1"
    assert furniture["position"] == {"x": 1.2, "y": 1.4}
    assert furniture["size"]["height_meters"] == 0.85


def test_load_layout_rejects_cross_user_access() -> None:
    from fastapi.testclient import TestClient

    repository = FakeLayoutRepository()
    record = save_record(repository)

    response = TestClient(configured_app(repository)).get(
        f"/room-projects/99/layouts/{record.id}",
        headers={"Authorization": "Bearer valid-token"},
    )

    assert response.status_code == 404
    assert response.json()["error"]["code"] == "not_found"


def test_export_latest_layout_returns_json_export_payload() -> None:
    from fastapi.testclient import TestClient

    repository = FakeLayoutRepository()
    save_record(repository)

    response = TestClient(configured_app(repository)).get(
        "/room-projects/1/layouts/latest/export",
        headers={"Authorization": "Bearer valid-token"},
    )

    assert response.status_code == 200
    body = response.json()
    export = body["data"]["export"]
    layout = export["layout"]
    furniture = layout["furniture_objects"][0]
    assert body["error"] is None
    assert body["meta"]["request_id"]
    assert export["format"] == "roomforge_layout_json"
    assert export["version"] == 1
    assert layout["room_dimensions"]["height_value"] == 2.7
    assert layout["floor_plan"]["coordinate_space"] == "meters"
    assert layout["source_metadata"]["source_image_id"] == 7
    assert furniture["category"] == "chair"
    assert furniture["rotation_degrees"] == 15


def test_export_layout_rejects_cross_user_access() -> None:
    from fastapi.testclient import TestClient

    repository = FakeLayoutRepository()
    record = save_record(repository)

    response = TestClient(configured_app(repository)).get(
        f"/room-projects/99/layouts/{record.id}/export",
        headers={"Authorization": "Bearer valid-token"},
    )

    assert response.status_code == 404
    assert response.json()["error"]["code"] == "not_found"


def test_save_load_export_round_trip_preserves_required_fields() -> None:
    from fastapi.testclient import TestClient

    repository = FakeLayoutRepository()
    client = TestClient(configured_app(repository))
    expected = layout_payload()

    save_response = client.post(
        "/room-projects/1/layouts",
        headers={"Authorization": "Bearer valid-token"},
        json=expected,
    )
    load_response = client.get(
        "/room-projects/1/layouts/latest",
        headers={"Authorization": "Bearer valid-token"},
    )
    export_response = client.get(
        "/room-projects/1/layouts/latest/export",
        headers={"Authorization": "Bearer valid-token"},
    )

    assert save_response.status_code == 201
    assert load_response.status_code == 200
    assert export_response.status_code == 200
    saved = required_layout_fields(save_response.json()["data"]["layout"])
    loaded = required_layout_fields(load_response.json()["data"]["layout"])
    exported = required_layout_fields(
        export_response.json()["data"]["export"]["layout"]
    )
    assert saved == expected
    assert loaded == expected
    assert exported == expected


def test_non_cv_api_p95_stays_under_one_second_for_layout_flow() -> None:
    from fastapi.testclient import TestClient

    repository = FakeLayoutRepository()
    app = configured_app(repository, project_repository=FakeProjectRepository())
    client = TestClient(app)
    headers = {"Authorization": "Bearer valid-token"}
    durations: list[float] = []

    for _ in range(20):
        started = perf_counter()
        assert client.get("/room-projects", headers=headers).status_code == 200
        durations.append(perf_counter() - started)

        started = perf_counter()
        assert client.get("/room-projects/1", headers=headers).status_code == 200
        durations.append(perf_counter() - started)

        started = perf_counter()
        save_response = client.post(
            "/room-projects/1/layouts",
            headers=headers,
            json=layout_payload(),
        )
        assert save_response.status_code == 201
        durations.append(perf_counter() - started)

        started = perf_counter()
        load_response = client.get(
            "/room-projects/1/layouts/latest",
            headers=headers,
        )
        assert load_response.status_code == 200
        durations.append(perf_counter() - started)

    assert p95_seconds(durations) < 1.0
