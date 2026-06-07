import json
from dataclasses import dataclass
from datetime import datetime
from typing import Any, Protocol

import oracledb

from app.core.config import Settings
from app.repositories.confirmed_geometries import ConfirmedGeometryNotFound
from app.repositories.users import UserRecord


@dataclass(frozen=True)
class FloorPlanRecord:
    id: int
    project_id: int
    user_id: int
    confirmed_geometry_id: int
    unit: str
    width_value: float
    depth_value: float
    width_deviation_ratio: float
    depth_deviation_ratio: float
    aspect_ratio_error: float
    perspective_assumptions: dict[str, Any]
    image_geometry: dict[str, Any]
    metric_geometry: dict[str, Any]
    created_at: datetime


@dataclass(frozen=True)
class FloorPlanCreate:
    confirmed_geometry_id: int
    reference_line: dict[str, Any]
    reference_length_value: float
    unit: str = "meters"


class FloorPlanNotFound(Exception):
    pass


class FloorPlanRepository(Protocol):
    def create_for_project(
        self, user: UserRecord, project_id: int, payload: FloorPlanCreate
    ) -> FloorPlanRecord:
        pass

    def get_for_project(self, user: UserRecord, project_id: int, floor_plan_id: int) -> FloorPlanRecord:
        pass

    def list_for_admin_confirmed_geometry(
        self, confirmed_geometry_id: int
    ) -> list[FloorPlanRecord]:
        pass


class OracleFloorPlanRepository:
    def __init__(self, settings: Settings) -> None:
        self._settings = settings

    def create_for_project(
        self, user: UserRecord, project_id: int, payload: FloorPlanCreate
    ) -> FloorPlanRecord:
        floor_plan_id = None
        with oracledb.connect(
            user=self._settings.oracle_user,
            password=self._settings.oracle_password,
            dsn=self._settings.oracle_dsn,
        ) as connection:
            with connection.cursor() as cursor:
                geometry_row = self._fetch_confirmed_geometry(
                    cursor, user.id, project_id, payload.confirmed_geometry_id
                )
                dimension_row = self._fetch_dimensions(cursor, user.id, project_id)
                if geometry_row is None or dimension_row is None:
                    raise ConfirmedGeometryNotFound()

                image_points = json.loads(str(read_lob_value(geometry_row[0])))
                width_value = float(dimension_row[0])
                depth_value = float(dimension_row[1])
                metric_geometry = metric_geometry_from_dimensions(width_value, depth_value)
                assumptions = {
                    "model": "mvp_rectangular_projection",
                    "reference_line": payload.reference_line,
                    "reference_length_value": payload.reference_length_value,
                    "source_coordinate_space": "image_pixels",
                    "target_coordinate_space": "meters",
                }
                floor_plan_id_var = cursor.var(oracledb.NUMBER)
                cursor.execute(
                    """
                    INSERT INTO floor_plans (
                      project_id,
                      user_id,
                      confirmed_geometry_id,
                      unit,
                      width_value,
                      depth_value,
                      width_deviation_ratio,
                      depth_deviation_ratio,
                      aspect_ratio_error,
                      perspective_assumptions_json,
                      image_geometry_json,
                      metric_geometry_json,
                      created_at
                    ) VALUES (
                      :project_id,
                      :user_id,
                      :confirmed_geometry_id,
                      :unit,
                      :width_value,
                      :depth_value,
                      0,
                      0,
                      0,
                      :perspective_assumptions_json,
                      :image_geometry_json,
                      :metric_geometry_json,
                      SYSTIMESTAMP
                    )
                    RETURNING id INTO :floor_plan_id
                    """,
                    project_id=project_id,
                    user_id=user.id,
                    confirmed_geometry_id=payload.confirmed_geometry_id,
                    unit=payload.unit,
                    width_value=width_value,
                    depth_value=depth_value,
                    perspective_assumptions_json=json.dumps(assumptions, separators=(",", ":")),
                    image_geometry_json=json.dumps(
                        {"coordinate_space": "image_pixels", "points": image_points},
                        separators=(",", ":"),
                    ),
                    metric_geometry_json=json.dumps(metric_geometry, separators=(",", ":")),
                    floor_plan_id=floor_plan_id_var,
                )
                connection.commit()
                floor_plan_id = int(floor_plan_id_var.getvalue()[0])
                row = self._fetch_floor_plan(cursor, user.id, project_id, floor_plan_id)

        if row is None or floor_plan_id is None:
            raise RuntimeError("Oracle floor plan creation failed.")
        return floor_plan_record_from_row(row)

    def get_for_project(self, user: UserRecord, project_id: int, floor_plan_id: int) -> FloorPlanRecord:
        with oracledb.connect(
            user=self._settings.oracle_user,
            password=self._settings.oracle_password,
            dsn=self._settings.oracle_dsn,
        ) as connection:
            with connection.cursor() as cursor:
                row = self._fetch_floor_plan(cursor, user.id, project_id, floor_plan_id)

        if row is None:
            raise FloorPlanNotFound()
        return floor_plan_record_from_row(row)

    def list_for_admin_confirmed_geometry(
        self, confirmed_geometry_id: int
    ) -> list[FloorPlanRecord]:
        with oracledb.connect(
            user=self._settings.oracle_user,
            password=self._settings.oracle_password,
            dsn=self._settings.oracle_dsn,
        ) as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    SELECT id, project_id, user_id, confirmed_geometry_id, unit,
                           width_value, depth_value, width_deviation_ratio,
                           depth_deviation_ratio, aspect_ratio_error,
                           perspective_assumptions_json, image_geometry_json,
                           metric_geometry_json, created_at
                    FROM floor_plans
                    WHERE confirmed_geometry_id = :confirmed_geometry_id
                    ORDER BY created_at DESC, id DESC
                    """,
                    confirmed_geometry_id=confirmed_geometry_id,
                )
                rows = cursor.fetchall()

        return [floor_plan_record_from_row(row) for row in rows]

    def _fetch_confirmed_geometry(self, cursor, user_id: int, project_id: int, geometry_id: int):
        cursor.execute(
            """
            SELECT points_json
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

    def _fetch_dimensions(self, cursor, user_id: int, project_id: int):
        cursor.execute(
            """
            SELECT width_value, depth_value
            FROM room_project_dimensions
            WHERE project_id = :project_id
              AND user_id = :user_id
            """,
            project_id=project_id,
            user_id=user_id,
        )
        return cursor.fetchone()

    def _fetch_floor_plan(self, cursor, user_id: int, project_id: int, floor_plan_id: int):
        cursor.execute(
            """
            SELECT id, project_id, user_id, confirmed_geometry_id, unit,
                   width_value, depth_value, width_deviation_ratio,
                   depth_deviation_ratio, aspect_ratio_error,
                   perspective_assumptions_json, image_geometry_json,
                   metric_geometry_json, created_at
            FROM floor_plans
            WHERE id = :floor_plan_id
              AND project_id = :project_id
              AND user_id = :user_id
            """,
            floor_plan_id=floor_plan_id,
            project_id=project_id,
            user_id=user_id,
        )
        return cursor.fetchone()


def metric_geometry_from_dimensions(width_value: float, depth_value: float) -> dict[str, Any]:
    return {
        "coordinate_space": "meters",
        "points": [
            {"x": 0, "y": 0},
            {"x": width_value, "y": 0},
            {"x": width_value, "y": depth_value},
            {"x": 0, "y": depth_value},
        ],
    }


def read_lob_value(value):
    return value.read() if hasattr(value, "read") else value


def floor_plan_record_from_row(row) -> FloorPlanRecord:
    return FloorPlanRecord(
        id=int(row[0]),
        project_id=int(row[1]),
        user_id=int(row[2]),
        confirmed_geometry_id=int(row[3]),
        unit=str(row[4]),
        width_value=float(row[5]),
        depth_value=float(row[6]),
        width_deviation_ratio=float(row[7]),
        depth_deviation_ratio=float(row[8]),
        aspect_ratio_error=float(row[9]),
        perspective_assumptions=json.loads(str(read_lob_value(row[10]))),
        image_geometry=json.loads(str(read_lob_value(row[11]))),
        metric_geometry=json.loads(str(read_lob_value(row[12]))),
        created_at=row[13],
    )
