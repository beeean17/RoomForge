from dataclasses import dataclass
from datetime import datetime
from typing import Protocol

import oracledb

from app.core.config import Settings
from app.repositories.projects import ProjectNotFound
from app.repositories.users import UserRecord


@dataclass(frozen=True)
class RoomDimensionsRecord:
    project_id: int
    user_id: int
    width_value: float
    depth_value: float
    height_value: float
    unit: str
    height_source: str
    created_at: datetime
    updated_at: datetime


@dataclass(frozen=True)
class RoomDimensionsUpsert:
    width_value: float
    depth_value: float
    height_value: float
    unit: str
    height_source: str


class RoomDimensionsNotFound(Exception):
    pass


class RoomDimensionsRepository(Protocol):
    def get_for_project(self, user: UserRecord, project_id: int) -> RoomDimensionsRecord:
        pass

    def upsert_for_project(
        self, user: UserRecord, project_id: int, payload: RoomDimensionsUpsert
    ) -> RoomDimensionsRecord:
        pass


class OracleRoomDimensionsRepository:
    def __init__(self, settings: Settings) -> None:
        self._settings = settings

    def get_for_project(self, user: UserRecord, project_id: int) -> RoomDimensionsRecord:
        with oracledb.connect(
            user=self._settings.oracle_user,
            password=self._settings.oracle_password,
            dsn=self._settings.oracle_dsn,
        ) as connection:
            with connection.cursor() as cursor:
                row = self._fetch_dimensions(cursor, user.id, project_id)

        if row is None:
            raise RoomDimensionsNotFound()
        return room_dimensions_record_from_row(row)

    def upsert_for_project(
        self, user: UserRecord, project_id: int, payload: RoomDimensionsUpsert
    ) -> RoomDimensionsRecord:
        with oracledb.connect(
            user=self._settings.oracle_user,
            password=self._settings.oracle_password,
            dsn=self._settings.oracle_dsn,
        ) as connection:
            with connection.cursor() as cursor:
                self._ensure_owned_project(cursor, user.id, project_id)
                cursor.execute(
                    """
                    MERGE INTO room_project_dimensions target
                    USING (
                      SELECT :project_id AS project_id, :user_id AS user_id FROM dual
                    ) source
                    ON (target.project_id = source.project_id AND target.user_id = source.user_id)
                    WHEN MATCHED THEN UPDATE SET
                      width_value = :width_value,
                      depth_value = :depth_value,
                      height_value = :height_value,
                      unit = :unit,
                      height_source = :height_source,
                      updated_at = SYSTIMESTAMP
                    WHEN NOT MATCHED THEN INSERT (
                      project_id,
                      user_id,
                      width_value,
                      depth_value,
                      height_value,
                      unit,
                      height_source,
                      created_at,
                      updated_at
                    ) VALUES (
                      :project_id,
                      :user_id,
                      :width_value,
                      :depth_value,
                      :height_value,
                      :unit,
                      :height_source,
                      SYSTIMESTAMP,
                      SYSTIMESTAMP
                    )
                    """,
                    project_id=project_id,
                    user_id=user.id,
                    width_value=payload.width_value,
                    depth_value=payload.depth_value,
                    height_value=payload.height_value,
                    unit=payload.unit,
                    height_source=payload.height_source,
                )
                connection.commit()
                row = self._fetch_dimensions(cursor, user.id, project_id)

        if row is None:
            raise RuntimeError("Oracle room dimensions upsert failed.")
        return room_dimensions_record_from_row(row)

    def _ensure_owned_project(self, cursor, user_id: int, project_id: int) -> None:
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
        if cursor.fetchone() is None:
            raise ProjectNotFound()

    def _fetch_dimensions(self, cursor, user_id: int, project_id: int):
        cursor.execute(
            """
            SELECT project_id, user_id, width_value, depth_value, height_value,
                   unit, height_source, created_at, updated_at
            FROM room_project_dimensions
            WHERE project_id = :project_id
              AND user_id = :user_id
            """,
            project_id=project_id,
            user_id=user_id,
        )
        return cursor.fetchone()


def room_dimensions_record_from_row(row) -> RoomDimensionsRecord:
    return RoomDimensionsRecord(
        project_id=int(row[0]),
        user_id=int(row[1]),
        width_value=float(row[2]),
        depth_value=float(row[3]),
        height_value=float(row[4]),
        unit=str(row[5]),
        height_source=str(row[6]),
        created_at=row[7],
        updated_at=row[8],
    )
