import json
from dataclasses import dataclass
from datetime import datetime
from typing import Any, Protocol

import oracledb

from app.core.config import Settings
from app.repositories.opencv_results import OpenCvResultNotFound
from app.repositories.users import UserRecord


@dataclass(frozen=True)
class ConfirmedGeometryRecord:
    id: int
    project_id: int
    user_id: int
    opencv_result_id: int | None
    coordinate_space: str
    geometry_kind: str
    points: list[dict[str, float]]
    created_at: datetime
    updated_at: datetime


@dataclass(frozen=True)
class ConfirmedGeometryCreate:
    opencv_result_id: int | None
    coordinate_space: str
    geometry_kind: str
    points: list[dict[str, float]]


class ConfirmedGeometryNotFound(Exception):
    pass


class ConfirmedGeometryRepository(Protocol):
    def create_for_project(
        self, user: UserRecord, project_id: int, payload: ConfirmedGeometryCreate
    ) -> ConfirmedGeometryRecord:
        pass

    def get_for_project(
        self, user: UserRecord, project_id: int, geometry_id: int
    ) -> ConfirmedGeometryRecord:
        pass

    def list_for_admin_opencv_result(
        self, opencv_result_id: int
    ) -> list[ConfirmedGeometryRecord]:
        pass


class OracleConfirmedGeometryRepository:
    def __init__(self, settings: Settings) -> None:
        self._settings = settings

    def create_for_project(
        self, user: UserRecord, project_id: int, payload: ConfirmedGeometryCreate
    ) -> ConfirmedGeometryRecord:
        geometry_id = None
        points_json = json.dumps(payload.points, separators=(",", ":"))
        with oracledb.connect(
            user=self._settings.oracle_user,
            password=self._settings.oracle_password,
            dsn=self._settings.oracle_dsn,
        ) as connection:
            with connection.cursor() as cursor:
                self._ensure_owned_project_or_result(
                    cursor,
                    user.id,
                    project_id,
                    payload.opencv_result_id,
                )
                geometry_id_var = cursor.var(oracledb.NUMBER)
                cursor.execute(
                    """
                    INSERT INTO confirmed_geometries (
                      project_id,
                      user_id,
                      opencv_result_id,
                      coordinate_space,
                      geometry_kind,
                      points_json,
                      created_at,
                      updated_at
                    ) VALUES (
                      :project_id,
                      :user_id,
                      :opencv_result_id,
                      :coordinate_space,
                      :geometry_kind,
                      :points_json,
                      SYSTIMESTAMP,
                      SYSTIMESTAMP
                    )
                    RETURNING id INTO :geometry_id
                    """,
                    project_id=project_id,
                    user_id=user.id,
                    opencv_result_id=payload.opencv_result_id,
                    coordinate_space=payload.coordinate_space,
                    geometry_kind=payload.geometry_kind,
                    points_json=points_json,
                    geometry_id=geometry_id_var,
                )
                connection.commit()
                geometry_id = int(geometry_id_var.getvalue()[0])
                row = self._fetch_geometry(cursor, user.id, project_id, geometry_id)

        if row is None or geometry_id is None:
            raise RuntimeError("Oracle confirmed geometry creation failed.")
        return confirmed_geometry_record_from_row(row)

    def get_for_project(
        self, user: UserRecord, project_id: int, geometry_id: int
    ) -> ConfirmedGeometryRecord:
        with oracledb.connect(
            user=self._settings.oracle_user,
            password=self._settings.oracle_password,
            dsn=self._settings.oracle_dsn,
        ) as connection:
            with connection.cursor() as cursor:
                row = self._fetch_geometry(cursor, user.id, project_id, geometry_id)

        if row is None:
            raise ConfirmedGeometryNotFound()
        return confirmed_geometry_record_from_row(row)

    def list_for_admin_opencv_result(
        self, opencv_result_id: int
    ) -> list[ConfirmedGeometryRecord]:
        with oracledb.connect(
            user=self._settings.oracle_user,
            password=self._settings.oracle_password,
            dsn=self._settings.oracle_dsn,
        ) as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    SELECT id, project_id, user_id, opencv_result_id, coordinate_space,
                           geometry_kind, points_json, created_at, updated_at
                    FROM confirmed_geometries
                    WHERE opencv_result_id = :opencv_result_id
                    ORDER BY updated_at DESC, id DESC
                    """,
                    opencv_result_id=opencv_result_id,
                )
                rows = cursor.fetchall()

        return [confirmed_geometry_record_from_row(row) for row in rows]

    def _ensure_owned_project_or_result(
        self, cursor, user_id: int, project_id: int, opencv_result_id: int | None
    ) -> None:
        if opencv_result_id is None:
            cursor.execute(
                """
                SELECT id
                FROM room_projects
                WHERE id = :project_id
                  AND user_id = :user_id
                  AND deleted_at IS NULL
                """,
                project_id=project_id,
                user_id=user_id,
            )
        else:
            cursor.execute(
                """
                SELECT id
                FROM opencv_results
                WHERE id = :opencv_result_id
                  AND project_id = :project_id
                  AND user_id = :user_id
                """,
                opencv_result_id=opencv_result_id,
                project_id=project_id,
                user_id=user_id,
            )
        if cursor.fetchone() is None:
            raise OpenCvResultNotFound()

    def _fetch_geometry(self, cursor, user_id: int, project_id: int, geometry_id: int):
        cursor.execute(
            """
            SELECT id, project_id, user_id, opencv_result_id, coordinate_space,
                   geometry_kind, points_json, created_at, updated_at
            FROM confirmed_geometries
            WHERE id = :geometry_id
              AND project_id = :project_id
              AND user_id = :user_id
            """,
            geometry_id=geometry_id,
            project_id=project_id,
            user_id=user_id,
        )
        return cursor.fetchone()


def confirmed_geometry_record_from_row(row) -> ConfirmedGeometryRecord:
    points_value = row[6]
    if hasattr(points_value, "read"):
        points_value = points_value.read()
    points = json.loads(str(points_value))
    return ConfirmedGeometryRecord(
        id=int(row[0]),
        project_id=int(row[1]),
        user_id=int(row[2]),
        opencv_result_id=int(row[3]) if row[3] is not None else None,
        coordinate_space=str(row[4]),
        geometry_kind=str(row[5]),
        points=[dict(point) for point in points],
        created_at=row[7],
        updated_at=row[8],
    )
