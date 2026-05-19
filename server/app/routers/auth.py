from fastapi import APIRouter, Depends, Request
from fastapi.security import HTTPAuthorizationCredentials

from app.auth.dependencies import (
    AuthErrorResponse,
    authenticate_request,
    bearer_scheme,
)
from app.core.request import request_id_from
from app.schemas.auth import SessionUser

router = APIRouter(prefix="/auth", tags=["auth"])


@router.get("/session")
def session(
    request: Request,
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
) -> dict[str, object]:
    try:
        user = authenticate_request(request, credentials)
    except AuthErrorResponse as exc:
        return exc.response

    return {
        "data": {
            "user": SessionUser(
                id=user.id,
                firebase_uid=user.firebase_uid,
                email=user.email,
                display_name=user.display_name,
                role=user.role,
            ).model_dump()
        },
        "error": None,
        "meta": {
            "request_id": request_id_from(request),
        },
    }
