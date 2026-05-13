from fastapi import Request
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.auth.firebase import (
    FirebaseAdminTokenVerifier,
    InvalidAuthToken,
    TokenVerifier,
)
from app.core.config import settings
from app.core.errors import error_response
from app.core.request import request_id_from
from app.repositories.users import OracleUserRepository, UserRecord, UserRepository

bearer_scheme = HTTPBearer(auto_error=False)


def token_verifier_from(request: Request) -> TokenVerifier:
    verifier = getattr(request.app.state, "token_verifier", None)
    if verifier is not None:
        return verifier

    verifier = FirebaseAdminTokenVerifier(settings)
    request.app.state.token_verifier = verifier
    return verifier


def user_repository_from(request: Request) -> UserRepository:
    repository = getattr(request.app.state, "user_repository", None)
    if repository is not None:
        return repository

    repository = OracleUserRepository(settings)
    request.app.state.user_repository = repository
    return repository


def authenticate_request(
    request: Request,
    credentials: HTTPAuthorizationCredentials | None,
) -> UserRecord:
    request_id = request_id_from(request)

    if credentials is None or credentials.scheme.lower() != "bearer":
        raise_auth_error(request_id)

    try:
        firebase_identity = token_verifier_from(request).verify_id_token(
            credentials.credentials
        )
        return user_repository_from(request).upsert_from_firebase(firebase_identity)
    except InvalidAuthToken:
        raise_auth_error(request_id)


def raise_auth_error(request_id: str) -> None:
    raise AuthErrorResponse(
        error_response(
            code="unauthenticated",
            message="A valid Firebase ID token is required.",
            status_code=401,
            request_id=request_id,
        )
    )


class AuthErrorResponse(Exception):
    def __init__(self, response):
        self.response = response
