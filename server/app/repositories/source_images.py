from dataclasses import dataclass
from datetime import datetime
from typing import Protocol

import oracledb

from app.core.config import Settings
from app.repositories.projects import ProjectNotFound
from app.repositories.users import UserRecord


@dataclass(frozen=True)
class SourceImageRecord:
    id: int
    project_id: int
    user_id: int
    original_filename: str
    stored_name: str
    content_type: str
    byte_size: int
    width_px: int | None
    height_px: int | None
    sha256_hex: str
    retention_status: str
    uploaded_at: datetime


@dataclass(frozen=True)
class SourceImageCreate:
    original_filename: str
    stored_name: str
    content_type: str
    byte_size: int
    width_px: int | None
    height_px: int | None
    sha256_hex: str
    image_bytes: bytes
    retention_status: str = "active"


class SourceImageNotFound(Exception):
    pass


class SourceImageRepository(Protocol):
    def create_for_project(
        self, user: UserRecord, project_id: int, payload: SourceImageCreate
    ) -> SourceImageRecord:
        pass

    def get_for_project(
        self, user: UserRecord, project_id: int, source_image_id: int
    ) -> SourceImageRecord:
        pass


class OracleSourceImageRepository:
    def __init__(self, settings: Settings) -> None:
        self._settings = settings

    def create_for_project(
        self, user: UserRecord, project_id: int, payload: SourceImageCreate
    ) -> SourceImageRecord:
        source_image_id = None
        with oracledb.connect(
            user=self._settings.oracle_user,
            password=self._settings.oracle_password,
            dsn=self._settings.oracle_dsn,
        ) as connection:
            with connection.cursor() as cursor:
                self._ensure_owned_project(cursor, user.id, project_id)
                source_image_id_var = cursor.var(oracledb.NUMBER)
                cursor.execute(
                    """
                    INSERT INTO source_images (
                      project_id,
                      user_id,
                      original_filename,
                      stored_name,
                      content_type,
                      byte_size,
                      width_px,
                      height_px,
                      sha256_hex,
                      retention_status,
                      image_blob,
                      uploaded_at
                    ) VALUES (
                      :project_id,
                      :user_id,
                      :original_filename,
                      :stored_name,
                      :content_type,
                      :byte_size,
                      :width_px,
                      :height_px,
                      :sha256_hex,
                      :retention_status,
                      :image_blob,
                      SYSTIMESTAMP
                    )
                    RETURNING id INTO :source_image_id
                    """,
                    project_id=project_id,
                    user_id=user.id,
                    original_filename=payload.original_filename,
                    stored_name=payload.stored_name,
                    content_type=payload.content_type,
                    byte_size=payload.byte_size,
                    width_px=payload.width_px,
                    height_px=payload.height_px,
                    sha256_hex=payload.sha256_hex,
                    retention_status=payload.retention_status,
                    image_blob=payload.image_bytes,
                    source_image_id=source_image_id_var,
                )
                connection.commit()
                source_image_id = int(source_image_id_var.getvalue()[0])
                row = self._fetch_source_image(cursor, user.id, project_id, source_image_id)

        if row is None or source_image_id is None:
            raise RuntimeError("Oracle source image creation failed.")

        return source_image_record_from_row(row)

    def get_for_project(
        self, user: UserRecord, project_id: int, source_image_id: int
    ) -> SourceImageRecord:
        with oracledb.connect(
            user=self._settings.oracle_user,
            password=self._settings.oracle_password,
            dsn=self._settings.oracle_dsn,
        ) as connection:
            with connection.cursor() as cursor:
                row = self._fetch_source_image(cursor, user.id, project_id, source_image_id)

        if row is None:
            raise SourceImageNotFound()
        return source_image_record_from_row(row)

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

    def _fetch_source_image(self, cursor, user_id: int, project_id: int, source_image_id: int):
        cursor.execute(
            """
            SELECT id, project_id, user_id, original_filename, stored_name,
                   content_type, byte_size, width_px, height_px, sha256_hex,
                   retention_status, uploaded_at
            FROM source_images
            WHERE id = :source_image_id
              AND project_id = :project_id
              AND user_id = :user_id
              AND deleted_at IS NULL
            """,
            source_image_id=source_image_id,
            project_id=project_id,
            user_id=user_id,
        )
        return cursor.fetchone()


def source_image_record_from_row(row) -> SourceImageRecord:
    return SourceImageRecord(
        id=int(row[0]),
        project_id=int(row[1]),
        user_id=int(row[2]),
        original_filename=str(row[3]),
        stored_name=str(row[4]),
        content_type=str(row[5]),
        byte_size=int(row[6]),
        width_px=int(row[7]) if row[7] is not None else None,
        height_px=int(row[8]) if row[8] is not None else None,
        sha256_hex=str(row[9]),
        retention_status=str(row[10]),
        uploaded_at=row[11],
    )
