from datetime import UTC, datetime
from hashlib import sha256
from typing import Any

from app.auth.firebase import FirebaseIdentity
from app.repositories.confirmed_geometries import (
    ConfirmedGeometryCreate,
    ConfirmedGeometryNotFound,
    ConfirmedGeometryRecord,
)
from app.repositories.dimensions import (
    RoomDimensionsNotFound,
    RoomDimensionsRecord,
    RoomDimensionsUpsert,
)
from app.repositories.floor_plans import (
    FloorPlanCreate,
    FloorPlanNotFound,
    FloorPlanRecord,
    metric_geometry_from_dimensions,
)
from app.repositories.layouts import LayoutNotFound, LayoutRecord, LayoutSave
from app.repositories.opencv_results import (
    OpenCvResultCreate,
    OpenCvResultNotFound,
    OpenCvResultRecord,
)
from app.repositories.projects import (
    ProjectCreate,
    ProjectNotFound,
    ProjectRecord,
    ProjectUpdate,
)
from app.repositories.reconstruction_jobs import (
    ReconstructionJobCreate,
    ReconstructionJobNotFound,
    ReconstructionJobRecord,
    ReconstructionJobTransitionRecord,
)
from app.repositories.source_images import (
    SourceImageCreate,
    SourceImageNotFound,
    SourceImageRecord,
)
from app.repositories.users import UserRecord


class InMemoryRoomForgeStore:
    def __init__(self) -> None:
        self.users: dict[str, UserRecord] = {}
        self.projects: dict[int, ProjectRecord] = {}
        self.deleted_project_ids: set[int] = set()
        self.source_images: dict[int, SourceImageRecord] = {}
        self.dimensions: dict[tuple[int, int], RoomDimensionsRecord] = {}
        self.reconstruction_jobs: dict[int, ReconstructionJobRecord] = {}
        self.job_transitions: dict[int, list[ReconstructionJobTransitionRecord]] = {}
        self.opencv_results: dict[int, OpenCvResultRecord] = {}
        self.confirmed_geometries: dict[int, ConfirmedGeometryRecord] = {}
        self.floor_plans: dict[int, FloorPlanRecord] = {}
        self.layouts: dict[int, LayoutRecord] = {}
        self._next_ids: dict[str, int] = {}

    def next_id(self, key: str) -> int:
        next_value = self._next_ids.get(key, 1)
        self._next_ids[key] = next_value + 1
        return next_value


class InMemoryUserRepository:
    def __init__(self, store: InMemoryRoomForgeStore) -> None:
        self._store = store

    def upsert_from_firebase(self, identity: FirebaseIdentity) -> UserRecord:
        existing = self._store.users.get(identity.firebase_uid)
        if existing is not None:
            user = UserRecord(
                id=existing.id,
                firebase_uid=identity.firebase_uid,
                email=identity.email,
                display_name=identity.display_name,
                role=existing.role,
            )
        else:
            user = UserRecord(
                id=self._store.next_id("users"),
                firebase_uid=identity.firebase_uid,
                email=identity.email,
                display_name=identity.display_name,
                role="user",
            )
        self._store.users[identity.firebase_uid] = user
        return user


class InMemoryProjectRepository:
    def __init__(self, store: InMemoryRoomForgeStore) -> None:
        self._store = store

    def list_for_user(self, user: UserRecord) -> list[ProjectRecord]:
        return sorted(
            [
                project
                for project in self._store.projects.values()
                if project.user_id == user.id and project.id not in self._store.deleted_project_ids
            ],
            key=lambda project: (project.updated_at, project.id),
            reverse=True,
        )

    def create_for_user(self, user: UserRecord, payload: ProjectCreate) -> ProjectRecord:
        now = utc_now()
        project = ProjectRecord(
            id=self._store.next_id("projects"),
            user_id=user.id,
            name=payload.name,
            description=payload.description,
            created_at=now,
            updated_at=now,
        )
        self._store.projects[project.id] = project
        return project

    def get_for_user(self, user: UserRecord, project_id: int) -> ProjectRecord:
        project = self._store.projects.get(project_id)
        if project is None or project.user_id != user.id or project.id in self._store.deleted_project_ids:
            raise ProjectNotFound()
        return project

    def update_for_user(
        self, user: UserRecord, project_id: int, payload: ProjectUpdate
    ) -> ProjectRecord:
        existing = self.get_for_user(user, project_id)
        updated = ProjectRecord(
            id=existing.id,
            user_id=existing.user_id,
            name=payload.name,
            description=payload.description,
            created_at=existing.created_at,
            updated_at=utc_now(),
        )
        self._store.projects[project_id] = updated
        return updated

    def delete_for_user(self, user: UserRecord, project_id: int) -> None:
        self.get_for_user(user, project_id)
        self._store.deleted_project_ids.add(project_id)


class InMemorySourceImageRepository:
    def __init__(self, store: InMemoryRoomForgeStore) -> None:
        self._store = store

    def create_for_project(
        self, user: UserRecord, project_id: int, payload: SourceImageCreate
    ) -> SourceImageRecord:
        ensure_project(self._store, user, project_id)
        record = SourceImageRecord(
            id=self._store.next_id("source_images"),
            project_id=project_id,
            user_id=user.id,
            original_filename=payload.original_filename,
            stored_name=payload.stored_name,
            content_type=payload.content_type,
            byte_size=payload.byte_size,
            width_px=payload.width_px,
            height_px=payload.height_px,
            sha256_hex=payload.sha256_hex or sha256(payload.image_bytes).hexdigest(),
            retention_status=payload.retention_status,
            uploaded_at=utc_now(),
        )
        self._store.source_images[record.id] = record
        return record

    def get_for_project(
        self, user: UserRecord, project_id: int, source_image_id: int
    ) -> SourceImageRecord:
        record = self._store.source_images.get(source_image_id)
        if record is None or record.user_id != user.id or record.project_id != project_id:
            raise SourceImageNotFound()
        return record


class InMemoryRoomDimensionsRepository:
    def __init__(self, store: InMemoryRoomForgeStore) -> None:
        self._store = store

    def get_for_project(self, user: UserRecord, project_id: int) -> RoomDimensionsRecord:
        record = self._store.dimensions.get((user.id, project_id))
        if record is None:
            raise RoomDimensionsNotFound()
        return record

    def upsert_for_project(
        self, user: UserRecord, project_id: int, payload: RoomDimensionsUpsert
    ) -> RoomDimensionsRecord:
        ensure_project(self._store, user, project_id)
        existing = self._store.dimensions.get((user.id, project_id))
        now = utc_now()
        record = RoomDimensionsRecord(
            project_id=project_id,
            user_id=user.id,
            width_value=payload.width_value,
            depth_value=payload.depth_value,
            height_value=payload.height_value,
            unit=payload.unit,
            height_source=payload.height_source,
            created_at=existing.created_at if existing else now,
            updated_at=now,
        )
        self._store.dimensions[(user.id, project_id)] = record
        return record


class InMemoryReconstructionJobRepository:
    def __init__(self, store: InMemoryRoomForgeStore) -> None:
        self._store = store

    def create_for_project(
        self, user: UserRecord, project_id: int, payload: ReconstructionJobCreate
    ) -> ReconstructionJobRecord:
        ensure_ready_for_reconstruction(self._store, user, project_id, payload.source_image_id)
        job = reconstruction_job_record(
            store=self._store,
            user=user,
            project_id=project_id,
            source_image_id=payload.source_image_id,
            status="created",
            provider=payload.provider,
            retry_of_job_id=payload.retry_of_job_id,
        )
        self._store.reconstruction_jobs[job.id] = job
        self._store.job_transitions[job.id] = [
            transition_record(self._store, job.id, "created", "api", None, "Reconstruction job created.")
        ]
        return job

    def get_for_project(
        self, user: UserRecord, project_id: int, job_id: int
    ) -> ReconstructionJobRecord:
        job = self._store.reconstruction_jobs.get(job_id)
        if job is None or job.user_id != user.id or job.project_id != project_id:
            raise ReconstructionJobNotFound()
        return job

    def list_transitions_for_job(
        self, user: UserRecord, project_id: int, job_id: int
    ) -> list[ReconstructionJobTransitionRecord]:
        self.get_for_project(user, project_id, job_id)
        return self._store.job_transitions.get(job_id, [])

    def retry_for_project(
        self, user: UserRecord, project_id: int, job_id: int
    ) -> ReconstructionJobRecord:
        original = self.get_for_project(user, project_id, job_id)
        retry = reconstruction_job_record(
            store=self._store,
            user=user,
            project_id=project_id,
            source_image_id=original.source_image_id,
            status="retrying",
            provider=original.provider,
            retry_of_job_id=original.id,
        )
        self._store.reconstruction_jobs[retry.id] = retry
        self._store.job_transitions[retry.id] = [
            transition_record(
                self._store,
                retry.id,
                "retrying",
                "user",
                "retry_requested",
                "User requested reconstruction retry.",
            )
        ]
        return retry

    def list_for_admin(
        self, status: str | None = None
    ) -> list[ReconstructionJobRecord]:
        records = list(self._store.reconstruction_jobs.values())
        if status is not None:
            records = [record for record in records if record.status == status]
        return sorted(
            records,
            key=lambda record: (record.updated_at, record.id),
            reverse=True,
        )

    def get_for_admin(self, job_id: int) -> ReconstructionJobRecord:
        job = self._store.reconstruction_jobs.get(job_id)
        if job is None:
            raise ReconstructionJobNotFound()
        return job

    def list_transitions_for_admin(
        self, job_id: int
    ) -> list[ReconstructionJobTransitionRecord]:
        self.get_for_admin(job_id)
        return self._store.job_transitions.get(job_id, [])

    def count_retries_for_admin(self, job_id: int) -> int:
        return len(
            [
                job
                for job in self._store.reconstruction_jobs.values()
                if job.retry_of_job_id == job_id
            ]
        )


class InMemoryOpenCvResultRepository:
    def __init__(self, store: InMemoryRoomForgeStore) -> None:
        self._store = store

    def create_for_job(
        self, user: UserRecord, project_id: int, payload: OpenCvResultCreate
    ) -> OpenCvResultRecord:
        ensure_job(self._store, user, project_id, payload.job_id)
        record = OpenCvResultRecord(
            id=self._store.next_id("opencv_results"),
            project_id=project_id,
            user_id=user.id,
            job_id=payload.job_id,
            coordinate_space=payload.coordinate_space,
            candidate_geometry=payload.candidate_geometry,
            confidence=payload.confidence,
            algorithm=payload.algorithm,
            created_at=utc_now(),
        )
        self._store.opencv_results[record.id] = record
        return record

    def get_for_project(
        self, user: UserRecord, project_id: int, result_id: int
    ) -> OpenCvResultRecord:
        record = self._store.opencv_results.get(result_id)
        if record is None or record.user_id != user.id or record.project_id != project_id:
            raise OpenCvResultNotFound()
        return record

    def get_latest_for_admin_job(self, job_id: int) -> OpenCvResultRecord:
        records = [
            record
            for record in self._store.opencv_results.values()
            if record.job_id == job_id
        ]
        if not records:
            raise OpenCvResultNotFound()
        return max(records, key=lambda record: (record.created_at, record.id))


class InMemoryConfirmedGeometryRepository:
    def __init__(self, store: InMemoryRoomForgeStore) -> None:
        self._store = store

    def create_for_project(
        self, user: UserRecord, project_id: int, payload: ConfirmedGeometryCreate
    ) -> ConfirmedGeometryRecord:
        if payload.opencv_result_id is None:
            ensure_project(self._store, user, project_id)
        else:
            ensure_opencv_result(self._store, user, project_id, payload.opencv_result_id)
        record = ConfirmedGeometryRecord(
            id=self._store.next_id("confirmed_geometries"),
            project_id=project_id,
            user_id=user.id,
            opencv_result_id=payload.opencv_result_id,
            coordinate_space=payload.coordinate_space,
            geometry_kind=payload.geometry_kind,
            points=payload.points,
            created_at=utc_now(),
            updated_at=utc_now(),
        )
        self._store.confirmed_geometries[record.id] = record
        return record

    def get_for_project(
        self, user: UserRecord, project_id: int, geometry_id: int
    ) -> ConfirmedGeometryRecord:
        record = self._store.confirmed_geometries.get(geometry_id)
        if record is None or record.user_id != user.id or record.project_id != project_id:
            raise ConfirmedGeometryNotFound()
        return record

    def list_for_admin_opencv_result(
        self, opencv_result_id: int
    ) -> list[ConfirmedGeometryRecord]:
        return [
            record
            for record in self._store.confirmed_geometries.values()
            if record.opencv_result_id == opencv_result_id
        ]


class InMemoryFloorPlanRepository:
    def __init__(self, store: InMemoryRoomForgeStore) -> None:
        self._store = store

    def create_for_project(
        self, user: UserRecord, project_id: int, payload: FloorPlanCreate
    ) -> FloorPlanRecord:
        geometry = ensure_confirmed_geometry(
            self._store, user, project_id, payload.confirmed_geometry_id
        )
        dimensions = self._store.dimensions.get((user.id, project_id))
        if dimensions is None:
            raise ConfirmedGeometryNotFound()
        assumptions = {
            "model": "mvp_rectangular_projection",
            "reference_line": payload.reference_line,
            "reference_length_value": payload.reference_length_value,
            "source_coordinate_space": "image_pixels",
            "target_coordinate_space": "meters",
        }
        record = FloorPlanRecord(
            id=self._store.next_id("floor_plans"),
            project_id=project_id,
            user_id=user.id,
            confirmed_geometry_id=payload.confirmed_geometry_id,
            unit=payload.unit,
            width_value=dimensions.width_value,
            depth_value=dimensions.depth_value,
            width_deviation_ratio=0,
            depth_deviation_ratio=0,
            aspect_ratio_error=0,
            perspective_assumptions=assumptions,
            image_geometry={"coordinate_space": "image_pixels", "points": geometry.points},
            metric_geometry=metric_geometry_from_dimensions(
                dimensions.width_value, dimensions.depth_value
            ),
            created_at=utc_now(),
        )
        self._store.floor_plans[record.id] = record
        return record

    def get_for_project(
        self, user: UserRecord, project_id: int, floor_plan_id: int
    ) -> FloorPlanRecord:
        record = self._store.floor_plans.get(floor_plan_id)
        if record is None or record.user_id != user.id or record.project_id != project_id:
            raise FloorPlanNotFound()
        return record

    def list_for_admin_confirmed_geometry(
        self, confirmed_geometry_id: int
    ) -> list[FloorPlanRecord]:
        return [
            record
            for record in self._store.floor_plans.values()
            if record.confirmed_geometry_id == confirmed_geometry_id
        ]


class InMemoryLayoutRepository:
    def __init__(self, store: InMemoryRoomForgeStore) -> None:
        self._store = store

    def save_for_project(
        self, user: UserRecord, project_id: int, payload: LayoutSave
    ) -> LayoutRecord:
        ensure_project(self._store, user, project_id)
        now = utc_now()
        record = LayoutRecord(
            id=self._store.next_id("layouts"),
            project_id=project_id,
            user_id=user.id,
            room_dimensions=payload.room_dimensions,
            floor_plan=payload.floor_plan,
            source_metadata=payload.source_metadata,
            furniture_objects=payload.furniture_objects,
            editor_scene=payload.editor_scene,
            created_at=now,
            updated_at=now,
        )
        self._store.layouts[record.id] = record
        return record

    def get_for_project(
        self, user: UserRecord, project_id: int, layout_id: int
    ) -> LayoutRecord:
        ensure_project(self._store, user, project_id)
        record = self._store.layouts.get(layout_id)
        if record is None or record.user_id != user.id or record.project_id != project_id:
            raise LayoutNotFound()
        return record

    def get_latest_for_project(
        self, user: UserRecord, project_id: int
    ) -> LayoutRecord:
        ensure_project(self._store, user, project_id)
        records = [
            record
            for record in self._store.layouts.values()
            if record.user_id == user.id and record.project_id == project_id
        ]
        if not records:
            raise LayoutNotFound()
        return max(records, key=lambda record: (record.updated_at, record.id))


def install_in_memory_repositories(app) -> None:
    store = InMemoryRoomForgeStore()
    app.state.in_memory_store = store
    app.state.user_repository = InMemoryUserRepository(store)
    app.state.project_repository = InMemoryProjectRepository(store)
    app.state.source_image_repository = InMemorySourceImageRepository(store)
    app.state.room_dimensions_repository = InMemoryRoomDimensionsRepository(store)
    app.state.reconstruction_job_repository = InMemoryReconstructionJobRepository(store)
    app.state.opencv_result_repository = InMemoryOpenCvResultRepository(store)
    app.state.confirmed_geometry_repository = InMemoryConfirmedGeometryRepository(store)
    app.state.floor_plan_repository = InMemoryFloorPlanRepository(store)
    app.state.layout_repository = InMemoryLayoutRepository(store)


def utc_now() -> datetime:
    return datetime.now(UTC)


def ensure_project(store: InMemoryRoomForgeStore, user: UserRecord, project_id: int) -> ProjectRecord:
    project = store.projects.get(project_id)
    if project is None or project.user_id != user.id or project.id in store.deleted_project_ids:
        raise ProjectNotFound()
    return project


def ensure_ready_for_reconstruction(
    store: InMemoryRoomForgeStore,
    user: UserRecord,
    project_id: int,
    source_image_id: int,
) -> None:
    ensure_project(store, user, project_id)
    source_image = store.source_images.get(source_image_id)
    if (
        source_image is None
        or source_image.user_id != user.id
        or source_image.project_id != project_id
        or (user.id, project_id) not in store.dimensions
    ):
        raise ProjectNotFound()


def ensure_job(
    store: InMemoryRoomForgeStore,
    user: UserRecord,
    project_id: int,
    job_id: int,
) -> ReconstructionJobRecord:
    job = store.reconstruction_jobs.get(job_id)
    if job is None or job.user_id != user.id or job.project_id != project_id:
        raise ReconstructionJobNotFound()
    return job


def ensure_opencv_result(
    store: InMemoryRoomForgeStore,
    user: UserRecord,
    project_id: int,
    result_id: int,
) -> OpenCvResultRecord:
    result = store.opencv_results.get(result_id)
    if result is None or result.user_id != user.id or result.project_id != project_id:
        raise OpenCvResultNotFound()
    return result


def ensure_confirmed_geometry(
    store: InMemoryRoomForgeStore,
    user: UserRecord,
    project_id: int,
    geometry_id: int,
) -> ConfirmedGeometryRecord:
    geometry = store.confirmed_geometries.get(geometry_id)
    if geometry is None or geometry.user_id != user.id or geometry.project_id != project_id:
        raise ConfirmedGeometryNotFound()
    return geometry


def reconstruction_job_record(
    *,
    store: InMemoryRoomForgeStore,
    user: UserRecord,
    project_id: int,
    source_image_id: int,
    status: str,
    provider: str,
    retry_of_job_id: int | None,
) -> ReconstructionJobRecord:
    now = utc_now()
    return ReconstructionJobRecord(
        id=store.next_id("reconstruction_jobs"),
        project_id=project_id,
        user_id=user.id,
        source_image_id=source_image_id,
        status=status,
        provider=provider,
        retry_of_job_id=retry_of_job_id,
        failure_reason_code=None,
        failure_reason_message=None,
        created_at=now,
        updated_at=now,
    )


def transition_record(
    store: InMemoryRoomForgeStore,
    job_id: int,
    status: str,
    actor: str,
    reason_code: str | None,
    reason_message: str | None,
) -> ReconstructionJobTransitionRecord:
    return ReconstructionJobTransitionRecord(
        id=store.next_id("reconstruction_job_transitions"),
        job_id=job_id,
        status=status,
        actor=actor,
        reason_code=reason_code,
        reason_message=reason_message,
        created_at=utc_now(),
    )
