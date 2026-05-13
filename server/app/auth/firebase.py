from dataclasses import dataclass
import os
from typing import Protocol

from firebase_admin import auth, credentials, get_app, initialize_app

from app.core.config import Settings


class InvalidAuthToken(Exception):
    pass


@dataclass(frozen=True)
class FirebaseIdentity:
    firebase_uid: str
    email: str | None = None
    display_name: str | None = None


class TokenVerifier(Protocol):
    def verify_id_token(self, token: str) -> FirebaseIdentity:
        pass


class FirebaseAdminTokenVerifier:
    def __init__(self, settings: Settings) -> None:
        self._settings = settings
        self._ensure_initialized()

    def verify_id_token(self, token: str) -> FirebaseIdentity:
        try:
            decoded = auth.verify_id_token(token, check_revoked=True)
        except Exception as exc:  # Firebase Admin normalizes several token errors.
            raise InvalidAuthToken("Firebase ID token is missing, expired, or invalid.") from exc

        firebase_uid = decoded.get("uid") or decoded.get("sub")
        if not firebase_uid:
            raise InvalidAuthToken("Firebase ID token does not contain a user id.")

        return FirebaseIdentity(
            firebase_uid=firebase_uid,
            email=decoded.get("email"),
            display_name=decoded.get("name"),
        )

    def _ensure_initialized(self) -> None:
        try:
            get_app()
            return
        except ValueError:
            pass

        if self._settings.firebase_auth_emulator_host:
            os.environ.setdefault(
                "FIREBASE_AUTH_EMULATOR_HOST",
                self._settings.firebase_auth_emulator_host,
            )

        options = {"projectId": self._settings.firebase_project_id}
        if self._settings.firebase_admin_credentials_path:
            credential = credentials.Certificate(
                self._settings.firebase_admin_credentials_path
            )
            initialize_app(credential, options=options)
        else:
            initialize_app(options=options)
