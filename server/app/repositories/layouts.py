import json
from dataclasses import dataclass
from datetime import datetime
from typing import Any, Protocol

import oracledb

from app.core.config import Settings
from app.repositories.projects import ProjectNotFound
from app.repositories.users import UserRecord


@dataclass(frozen=True)
class LayoutRecord:
    id: int
    project_id: int
    user_id: int
    room_dimensions: dict[str, Any]
    floor_plan: dict[str, Any]
    source_metadata: dict[str, Any]
    furniture_objects: list[dict[str, Any]]
    editor_scene: dict[str, Any]
    created_at: datetime
    updated_at: datetime


@dataclass(frozen=True)
class LayoutSave:
    room_dimensions: dict[str, Any]
    floor_plan: dict[str, Any]
    source_metadata: dict[str, Any]
    furniture_objects: list[dict[str, Any]]
    editor_scene: dict[str, Any]


class LayoutNotFound(Exception):
    pass


class LayoutRepository(Protocol):
    def save_for_project(
        self, user: UserRecord, project_id: int, payload: LayoutSave
    ) -> LayoutRecord:
        pass


class OracleLayoutRepository:
    def __init__(self, settings: Settings) -> None:
        self._settings = settings

    def save_for_project(
        self, user: UserRecord, project_id: int, payload: LayoutSave
    ) -> LayoutRecord:
        layout_id = None
        with oracledb.connect(
            user=self._settings.oracle_user,
            password=self._settings.oracle_password,
            dsn=self._settings.oracle_dsn,
        ) as connection:
            with connection.cursor() as cursor:
                if self._fetch_project(cursor, user.id, project_id) is None:
                    raise ProjectNotFound()

                layout_id_var = cursor.var(oracledb.NUMBER)
                cursor.execute(
                    """
                    INSERT INTO layouts (
                      project_id,
                      user_id,
                      room_dimensions_json,
                      floor_plan_json,
                      source_metadata_json,
                      furniture_objects_json,
                      editor_scene_json,
                      created_at,
                      updated_at
                    ) VALUES (
                      :project_id,
                      :user_id,
                      :room_dimensions_json,
                      :floor_plan_json,
                      :source_metadata_json,
                      :furniture_objects_json,
                      :editor_scene_json,
                      SYSTIMESTAMP,
                      SYSTIMESTAMP
                    )
                    RETURNING id INTO :layout_id
                    """,
                    project_id=project_id,
                    user_id=user.id,
                    room_dimensions_json=json.dumps(
                        payload.room_dimensions, separators=(",", ":")
                    ),
                    floor_plan_json=json.dumps(payload.floor_plan, separators=(",", ":")),
                    source_metadata_json=json.dumps(payload.source_metadata, separators=(",", ":")),
                    furniture_objects_json=json.dumps(
                        payload.furniture_objects, separators=(",", ":")
                    ),
                    editor_scene_json=json.dumps(
                        payload.editor_scene, separators=(",", ":")
                    ),
                    layout_id=layout_id_var,
                )
                connection.commit()
                layout_id = int(layout_id_var.getvalue()[0])
                row = self._fetch_layout(cursor, user.id, project_id, layout_id)

        if row is None or layout_id is None:
            raise RuntimeError("Oracle layout save failed.")
        return layout_record_from_row(row)

    def _fetch_project(self, cursor, user_id: int, project_id: int):
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
        return cursor.fetchone()

    def _fetch_layout(self, cursor, user_id: int, project_id: int, layout_id: int):
        cursor.execute(
            """
            SELECT id, project_id, user_id, room_dimensions_json, floor_plan_json,
                   source_metadata_json, furniture_objects_json, editor_scene_json,
                   created_at, updated_at
            FROM layouts
            WHERE id = :layout_id
              AND project_id = :project_id
              AND user_id = :user_id
            """,
            layout_id=layout_id,
            project_id=project_id,
            user_id=user_id,
        )
        return cursor.fetchone()


def read_lob_value(value):
    return value.read() if hasattr(value, "read") else value


def layout_record_from_row(row) -> LayoutRecord:
    return LayoutRecord(
        id=int(row[0]),
        project_id=int(row[1]),
        user_id=int(row[2]),
        room_dimensions=json.loads(str(read_lob_value(row[3]))),
        floor_plan=json.loads(str(read_lob_value(row[4]))),
        source_metadata=json.loads(str(read_lob_value(row[5]))),
        furniture_objects=json.loads(str(read_lob_value(row[6]))),
        editor_scene=json.loads(str(read_lob_value(row[7]))),
        created_at=row[8],
        updated_at=row[9],
    )
