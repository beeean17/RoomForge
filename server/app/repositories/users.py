from dataclasses import dataclass
from typing import Protocol

import oracledb

from app.auth.firebase import FirebaseIdentity
from app.core.config import Settings


@dataclass(frozen=True)
class UserRecord:
    id: int
    firebase_uid: str
    email: str | None
    display_name: str | None
    role: str


class UserRepository(Protocol):
    def upsert_from_firebase(self, identity: FirebaseIdentity) -> UserRecord:
        pass


class OracleUserRepository:
    def __init__(self, settings: Settings) -> None:
        self._settings = settings

    def upsert_from_firebase(self, identity: FirebaseIdentity) -> UserRecord:
        with oracledb.connect(
            user=self._settings.oracle_user,
            password=self._settings.oracle_password,
            dsn=self._settings.oracle_dsn,
        ) as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    MERGE INTO users dst
                    USING (
                      SELECT
                        :firebase_uid AS firebase_uid,
                        :email AS email,
                        :display_name AS display_name
                      FROM dual
                    ) src
                    ON (dst.firebase_uid = src.firebase_uid)
                    WHEN MATCHED THEN UPDATE SET
                      dst.email = src.email,
                      dst.display_name = src.display_name,
                      dst.updated_at = SYSTIMESTAMP
                    WHEN NOT MATCHED THEN INSERT (
                      firebase_uid,
                      email,
                      display_name,
                      role,
                      created_at,
                      updated_at
                    ) VALUES (
                      src.firebase_uid,
                      src.email,
                      src.display_name,
                      'user',
                      SYSTIMESTAMP,
                      SYSTIMESTAMP
                    )
                    """,
                    firebase_uid=identity.firebase_uid,
                    email=identity.email,
                    display_name=identity.display_name,
                )
                connection.commit()

                cursor.execute(
                    """
                    SELECT id, firebase_uid, email, display_name, role
                    FROM users
                    WHERE firebase_uid = :firebase_uid
                    """,
                    firebase_uid=identity.firebase_uid,
                )
                row = cursor.fetchone()

        if row is None:
            raise RuntimeError("Oracle user mapping failed.")

        return UserRecord(
            id=int(row[0]),
            firebase_uid=str(row[1]),
            email=row[2],
            display_name=row[3],
            role=str(row[4]),
        )
