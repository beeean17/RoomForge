from dataclasses import dataclass
from datetime import datetime
from typing import Protocol

import oracledb

from app.core.config import Settings
from app.repositories.projects import ProjectNotFound
from app.repositories.users import UserRecord

ALLOWED_RECONSTRUCTION_STATUSES = {
    "created",
    "uploading",
    "processing",
    "review_required",
    "succeeded",
    "failed",
    "timeout",
    "cancelled",
    "retrying",
}

TERMINAL_RECONSTRUCTION_STATUSES = {
    "succeeded",
    "failed",
    "timeout",
    "cancelled",
}


@dataclass(frozen=True)
class ReconstructionJobRecord:
    id: int
    project_id: int
    user_id: int
    source_image_id: int
    status: str
    provider: str
    retry_of_job_id: int | None
    failure_reason_code: str | None
    failure_reason_message: str | None
    created_at: datetime
    updated_at: datetime


@dataclass(frozen=True)
class ReconstructionJobTransitionRecord:
    id: int
    job_id: int
    status: str
    actor: str
    reason_code: str | None
    reason_message: str | None
    created_at: datetime


@dataclass(frozen=True)
class ReconstructionJobCreate:
    source_image_id: int
    provider: str = "browser-opencv"
    retry_of_job_id: int | None = None


class ReconstructionJobNotFound(Exception):
    pass


class ReconstructionJobRepository(Protocol):
    def create_for_project(
        self, user: UserRecord, project_id: int, payload: ReconstructionJobCreate
    ) -> ReconstructionJobRecord:
        pass

    def get_for_project(
        self, user: UserRecord, project_id: int, job_id: int
    ) -> ReconstructionJobRecord:
        pass

    def list_transitions_for_job(
        self, user: UserRecord, project_id: int, job_id: int
    ) -> list[ReconstructionJobTransitionRecord]:
        pass


class OracleReconstructionJobRepository:
    def __init__(self, settings: Settings) -> None:
        self._settings = settings

    def create_for_project(
        self, user: UserRecord, project_id: int, payload: ReconstructionJobCreate
    ) -> ReconstructionJobRecord:
        job_id = None
        with oracledb.connect(
            user=self._settings.oracle_user,
            password=self._settings.oracle_password,
            dsn=self._settings.oracle_dsn,
        ) as connection:
            with connection.cursor() as cursor:
                self._ensure_project_ready(cursor, user.id, project_id, payload.source_image_id)
                job_id_var = cursor.var(oracledb.NUMBER)
                cursor.execute(
                    """
                    INSERT INTO reconstruction_jobs (
                      project_id,
                      user_id,
                      source_image_id,
                      status,
                      provider,
                      retry_of_job_id,
                      created_at,
                      updated_at
                    ) VALUES (
                      :project_id,
                      :user_id,
                      :source_image_id,
                      'created',
                      :provider,
                      :retry_of_job_id,
                      SYSTIMESTAMP,
                      SYSTIMESTAMP
                    )
                    RETURNING id INTO :job_id
                    """,
                    project_id=project_id,
                    user_id=user.id,
                    source_image_id=payload.source_image_id,
                    provider=payload.provider,
                    retry_of_job_id=payload.retry_of_job_id,
                    job_id=job_id_var,
                )
                job_id = int(job_id_var.getvalue()[0])
                cursor.execute(
                    """
                    INSERT INTO reconstruction_job_transitions (
                      job_id,
                      status,
                      actor,
                      reason_code,
                      reason_message,
                      created_at
                    ) VALUES (
                      :job_id,
                      'created',
                      'api',
                      NULL,
                      'Reconstruction job created.',
                      SYSTIMESTAMP
                    )
                    """,
                    job_id=job_id,
                )
                connection.commit()
                row = self._fetch_job(cursor, user.id, project_id, job_id)

        if row is None or job_id is None:
            raise RuntimeError("Oracle reconstruction job creation failed.")
        return reconstruction_job_record_from_row(row)

    def get_for_project(
        self, user: UserRecord, project_id: int, job_id: int
    ) -> ReconstructionJobRecord:
        with oracledb.connect(
            user=self._settings.oracle_user,
            password=self._settings.oracle_password,
            dsn=self._settings.oracle_dsn,
        ) as connection:
            with connection.cursor() as cursor:
                row = self._fetch_job(cursor, user.id, project_id, job_id)

        if row is None:
            raise ReconstructionJobNotFound()
        return reconstruction_job_record_from_row(row)

    def list_transitions_for_job(
        self, user: UserRecord, project_id: int, job_id: int
    ) -> list[ReconstructionJobTransitionRecord]:
        with oracledb.connect(
            user=self._settings.oracle_user,
            password=self._settings.oracle_password,
            dsn=self._settings.oracle_dsn,
        ) as connection:
            with connection.cursor() as cursor:
                if self._fetch_job(cursor, user.id, project_id, job_id) is None:
                    raise ReconstructionJobNotFound()
                cursor.execute(
                    """
                    SELECT id, job_id, status, actor, reason_code, reason_message, created_at
                    FROM reconstruction_job_transitions
                    WHERE job_id = :job_id
                    ORDER BY created_at ASC, id ASC
                    """,
                    job_id=job_id,
                )
                rows = cursor.fetchall()

        return [reconstruction_job_transition_record_from_row(row) for row in rows]

    def _ensure_project_ready(
        self, cursor, user_id: int, project_id: int, source_image_id: int
    ) -> None:
        cursor.execute(
            """
            SELECT p.id
            FROM room_projects p
            JOIN source_images s
              ON s.project_id = p.id
             AND s.user_id = p.user_id
             AND s.id = :source_image_id
             AND s.deleted_at IS NULL
            JOIN room_project_dimensions d
              ON d.project_id = p.id
             AND d.user_id = p.user_id
            WHERE p.id = :project_id
              AND p.user_id = :user_id
              AND p.deleted_at IS NULL
            """,
            source_image_id=source_image_id,
            project_id=project_id,
            user_id=user_id,
        )
        if cursor.fetchone() is None:
            raise ProjectNotFound()

    def _fetch_job(self, cursor, user_id: int, project_id: int, job_id: int):
        cursor.execute(
            """
            SELECT id, project_id, user_id, source_image_id, status, provider,
                   retry_of_job_id, failure_reason_code, failure_reason_message,
                   created_at, updated_at
            FROM reconstruction_jobs
            WHERE id = :job_id
              AND project_id = :project_id
              AND user_id = :user_id
            """,
            job_id=job_id,
            project_id=project_id,
            user_id=user_id,
        )
        return cursor.fetchone()


def reconstruction_job_record_from_row(row) -> ReconstructionJobRecord:
    return ReconstructionJobRecord(
        id=int(row[0]),
        project_id=int(row[1]),
        user_id=int(row[2]),
        source_image_id=int(row[3]),
        status=str(row[4]),
        provider=str(row[5]),
        retry_of_job_id=int(row[6]) if row[6] is not None else None,
        failure_reason_code=row[7],
        failure_reason_message=row[8],
        created_at=row[9],
        updated_at=row[10],
    )


def reconstruction_job_transition_record_from_row(
    row,
) -> ReconstructionJobTransitionRecord:
    return ReconstructionJobTransitionRecord(
        id=int(row[0]),
        job_id=int(row[1]),
        status=str(row[2]),
        actor=str(row[3]),
        reason_code=row[4],
        reason_message=row[5],
        created_at=row[6],
    )
