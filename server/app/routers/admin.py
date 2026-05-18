from fastapi import APIRouter, Depends, Request
from fastapi.security import HTTPAuthorizationCredentials

from app.auth.dependencies import (
    AuthErrorResponse,
    authorize_admin_request,
    bearer_scheme,
)
from app.core.request import request_id_from
from app.schemas.auth import SessionUser

router = APIRouter(prefix="/admin", tags=["admin"])


@router.get("/session")
def admin_session(
    request: Request,
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
) -> dict[str, object]:
    try:
        admin = authorize_admin_request(request, credentials)
    except AuthErrorResponse as exc:
        return exc.response

    return {
        "data": {
            "admin": SessionUser(
                id=admin.id,
                firebase_uid=admin.firebase_uid,
                email=admin.email,
                display_name=admin.display_name,
                role=admin.role,
            ).model_dump(),
            "capabilities": [],
        },
        "error": None,
        "meta": {"request_id": request_id_from(request)},
    }
