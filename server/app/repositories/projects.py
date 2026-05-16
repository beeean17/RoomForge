from dataclasses import dataclass
from datetime import datetime
from typing import Protocol

import oracledb

from app.core.config import Settings
from app.repositories.users import UserRecord


@dataclass(frozen=True)
class ProjectRecord:
    id: int
    user_id: int
    name: str
    description: str | None
    created_at: datetime
    updated_at: datetime


@dataclass(frozen=True)
class ProjectCreate:
    name: str
    description: str | None = None


@dataclass(frozen=True)
class ProjectUpdate:
    name: str
    description: str | None = None


class ProjectNotFound(Exception):
    pass


class ProjectRepository(Protocol):
    def list_for_user(self, user: UserRecord) -> list[ProjectRecord]:
        pass

    def create_for_user(self, user: UserRecord, payload: ProjectCreate) -> ProjectRecord:
        pass

    def get_for_user(self, user: UserRecord, project_id: int) -> ProjectRecord:
        pass

    def update_for_user(
        self, user: UserRecord, project_id: int, payload: ProjectUpdate
    ) -> ProjectRecord:
        pass

    def delete_for_user(self, user: UserRecord, project_id: int) -> None:
        pass


class OracleProjectRepository:
    def __init__(self, settings: Settings) -> None:
        self._settings = settings

    def list_for_user(self, user: UserRecord) -> list[ProjectRecord]:
        with oracledb.connect(
            user=self._settings.oracle_user,
            password=self._settings.oracle_password,
            dsn=self._settings.oracle_dsn,
        ) as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    SELECT id, user_id, name, description, created_at, updated_at
                    FROM room_projects
                    WHERE user_id = :user_id
                      AND deleted_at IS NULL
                    ORDER BY updated_at DESC, id DESC
                    """,
                    user_id=user.id,
                )
                rows = cursor.fetchall()

        return [project_record_from_row(row) for row in rows]

    def create_for_user(self, user: UserRecord, payload: ProjectCreate) -> ProjectRecord:
        project_id = None
        with oracledb.connect(
            user=self._settings.oracle_user,
            password=self._settings.oracle_password,
            dsn=self._settings.oracle_dsn,
        ) as connection:
            with connection.cursor() as cursor:
                project_id_var = cursor.var(oracledb.NUMBER)
                cursor.execute(
                    """
                    INSERT INTO room_projects (
                      user_id,
                      name,
                      description,
                      created_at,
                      updated_at
                    ) VALUES (
                      :user_id,
                      :name,
                      :description,
                      SYSTIMESTAMP,
                      SYSTIMESTAMP
                    )
                    RETURNING id INTO :project_id
                    """,
                    user_id=user.id,
                    name=payload.name,
                    description=payload.description,
                    project_id=project_id_var,
                )
                connection.commit()
                project_id = int(project_id_var.getvalue()[0])

                cursor.execute(
                    """
                    SELECT id, user_id, name, description, created_at, updated_at
                    FROM room_projects
                    WHERE id = :project_id AND user_id = :user_id
                    """,
                    project_id=project_id,
                    user_id=user.id,
                )
                row = cursor.fetchone()

        if row is None or project_id is None:
            raise RuntimeError("Oracle project creation failed.")

        return project_record_from_row(row)

    def get_for_user(self, user: UserRecord, project_id: int) -> ProjectRecord:
        with oracledb.connect(
            user=self._settings.oracle_user,
            password=self._settings.oracle_password,
            dsn=self._settings.oracle_dsn,
        ) as connection:
            with connection.cursor() as cursor:
                row = self._fetch_project(cursor, user.id, project_id)

        if row is None:
            raise ProjectNotFound()
        return project_record_from_row(row)

    def update_for_user(
        self, user: UserRecord, project_id: int, payload: ProjectUpdate
    ) -> ProjectRecord:
        with oracledb.connect(
            user=self._settings.oracle_user,
            password=self._settings.oracle_password,
            dsn=self._settings.oracle_dsn,
        ) as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    UPDATE room_projects
                    SET name = :name,
                        description = :description,
                        updated_at = SYSTIMESTAMP
                    WHERE id = :project_id
                      AND user_id = :user_id
                      AND deleted_at IS NULL
                    """,
                    name=payload.name,
                    description=payload.description,
                    project_id=project_id,
                    user_id=user.id,
                )
                if cursor.rowcount == 0:
                    raise ProjectNotFound()
                connection.commit()
                row = self._fetch_project(cursor, user.id, project_id)

        if row is None:
            raise ProjectNotFound()
        return project_record_from_row(row)

    def delete_for_user(self, user: UserRecord, project_id: int) -> None:
        with oracledb.connect(
            user=self._settings.oracle_user,
            password=self._settings.oracle_password,
            dsn=self._settings.oracle_dsn,
        ) as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    UPDATE room_projects
                    SET deleted_at = SYSTIMESTAMP,
                        updated_at = SYSTIMESTAMP
                    WHERE id = :project_id
                      AND user_id = :user_id
                      AND deleted_at IS NULL
                    """,
                    project_id=project_id,
                    user_id=user.id,
                )
                if cursor.rowcount == 0:
                    raise ProjectNotFound()
                connection.commit()

    def _fetch_project(self, cursor, user_id: int, project_id: int):
        cursor.execute(
            """
            SELECT id, user_id, name, description, created_at, updated_at
            FROM room_projects
            WHERE id = :project_id
              AND user_id = :user_id
              AND deleted_at IS NULL
            """,
            project_id=project_id,
            user_id=user_id,
        )
        return cursor.fetchone()


def project_record_from_row(row) -> ProjectRecord:
    return ProjectRecord(
        id=int(row[0]),
        user_id=int(row[1]),
        name=str(row[2]),
        description=row[3],
        created_at=row[4],
        updated_at=row[5],
    )
