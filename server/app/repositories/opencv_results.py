import json
from dataclasses import dataclass
from datetime import datetime
from typing import Any, Protocol

import oracledb

from app.core.config import Settings
from app.repositories.reconstruction_jobs import ReconstructionJobNotFound
from app.repositories.users import UserRecord


@dataclass(frozen=True)
class OpenCvResultRecord:
    id: int
    project_id: int
    user_id: int
    job_id: int
    coordinate_space: str
    candidate_geometry: dict[str, Any]
    confidence: float | None
    algorithm: str
    created_at: datetime


@dataclass(frozen=True)
class OpenCvResultCreate:
    job_id: int
    coordinate_space: str
    candidate_geometry: dict[str, Any]
    confidence: float | None
    algorithm: str = "roomforge-browser-opencv-stub"


class OpenCvResultNotFound(Exception):
    pass


class OpenCvResultRepository(Protocol):
    def create_for_job(
        self, user: UserRecord, project_id: int, payload: OpenCvResultCreate
    ) -> OpenCvResultRecord:
        pass

    def get_for_project(
        self, user: UserRecord, project_id: int, result_id: int
    ) -> OpenCvResultRecord:
        pass

    def get_latest_for_admin_job(self, job_id: int) -> OpenCvResultRecord:
        pass


class OracleOpenCvResultRepository:
    def __init__(self, settings: Settings) -> None:
        self._settings = settings

    def create_for_job(
        self, user: UserRecord, project_id: int, payload: OpenCvResultCreate
    ) -> OpenCvResultRecord:
        result_id = None
        geometry_json = json.dumps(payload.candidate_geometry, separators=(",", ":"))
        with oracledb.connect(
            user=self._settings.oracle_user,
            password=self._settings.oracle_password,
            dsn=self._settings.oracle_dsn,
        ) as connection:
            with connection.cursor() as cursor:
                self._ensure_owned_job(cursor, user.id, project_id, payload.job_id)
                result_id_var = cursor.var(oracledb.NUMBER)
                cursor.execute(
                    """
                    INSERT INTO opencv_results (
                      project_id,
                      user_id,
                      job_id,
                      coordinate_space,
                      candidate_geometry_json,
                      confidence,
                      algorithm,
                      created_at
                    ) VALUES (
                      :project_id,
                      :user_id,
                      :job_id,
                      :coordinate_space,
                      :candidate_geometry_json,
                      :confidence,
                      :algorithm,
                      SYSTIMESTAMP
                    )
                    RETURNING id INTO :result_id
                    """,
                    project_id=project_id,
                    user_id=user.id,
                    job_id=payload.job_id,
                    coordinate_space=payload.coordinate_space,
                    candidate_geometry_json=geometry_json,
                    confidence=payload.confidence,
                    algorithm=payload.algorithm,
                    result_id=result_id_var,
                )
                connection.commit()
                result_id = int(result_id_var.getvalue()[0])
                row = self._fetch_result(cursor, user.id, project_id, result_id)

        if row is None or result_id is None:
            raise RuntimeError("Oracle OpenCV result creation failed.")
        return opencv_result_record_from_row(row)

    def get_for_project(
        self, user: UserRecord, project_id: int, result_id: int
    ) -> OpenCvResultRecord:
        with oracledb.connect(
            user=self._settings.oracle_user,
            password=self._settings.oracle_password,
            dsn=self._settings.oracle_dsn,
        ) as connection:
            with connection.cursor() as cursor:
                row = self._fetch_result(cursor, user.id, project_id, result_id)

        if row is None:
            raise OpenCvResultNotFound()
        return opencv_result_record_from_row(row)

    def get_latest_for_admin_job(self, job_id: int) -> OpenCvResultRecord:
        with oracledb.connect(
            user=self._settings.oracle_user,
            password=self._settings.oracle_password,
            dsn=self._settings.oracle_dsn,
        ) as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    SELECT id, project_id, user_id, job_id, coordinate_space,
                           candidate_geometry_json, confidence, algorithm, created_at
                    FROM opencv_results
                    WHERE job_id = :job_id
                    ORDER BY created_at DESC, id DESC
                    FETCH FIRST 1 ROWS ONLY
                    """,
                    job_id=job_id,
                )
                row = cursor.fetchone()

        if row is None:
            raise OpenCvResultNotFound()
        return opencv_result_record_from_row(row)

    def _ensure_owned_job(self, cursor, user_id: int, project_id: int, job_id: int) -> None:
        cursor.execute(
            """
            SELECT id
            FROM reconstruction_jobs
            WHERE id = :job_id
              AND project_id = :project_id
              AND user_id = :user_id
            """,
            job_id=job_id,
            project_id=project_id,
            user_id=user_id,
        )
        if cursor.fetchone() is None:
            raise ReconstructionJobNotFound()

    def _fetch_result(self, cursor, user_id: int, project_id: int, result_id: int):
        cursor.execute(
            """
            SELECT id, project_id, user_id, job_id, coordinate_space,
                   candidate_geometry_json, confidence, algorithm, created_at
            FROM opencv_results
            WHERE id = :result_id
              AND project_id = :project_id
              AND user_id = :user_id
            """,
            result_id=result_id,
            project_id=project_id,
            user_id=user_id,
        )
        return cursor.fetchone()


def opencv_result_record_from_row(row) -> OpenCvResultRecord:
    geometry_value = row[5]
    if hasattr(geometry_value, "read"):
        geometry_value = geometry_value.read()
    return OpenCvResultRecord(
        id=int(row[0]),
        project_id=int(row[1]),
        user_id=int(row[2]),
        job_id=int(row[3]),
        coordinate_space=str(row[4]),
        candidate_geometry=json.loads(str(geometry_value)),
        confidence=float(row[6]) if row[6] is not None else None,
        algorithm=str(row[7]),
        created_at=row[8],
    )
