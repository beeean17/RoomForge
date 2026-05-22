from fastapi import APIRouter, Depends, Request
from fastapi.security import HTTPAuthorizationCredentials

from app.auth.dependencies import (
    AuthErrorResponse,
    authorize_admin_request,
    bearer_scheme,
)
from app.core.config import settings
from app.core.errors import error_response
from app.core.request import request_id_from
from app.repositories.reconstruction_jobs import (
    ALLOWED_RECONSTRUCTION_STATUSES,
    OracleReconstructionJobRepository,
    ReconstructionJobRepository,
)
from app.routers.reconstruction_jobs import reconstruction_job_response_from
from app.schemas.auth import SessionUser

router = APIRouter(prefix="/admin", tags=["admin"])

ALLOWED_ADMIN_JOB_STATUSES = (
    "created",
    "uploading",
    "processing",
    "review_required",
    "succeeded",
    "failed",
    "timeout",
    "cancelled",
    "retrying",
)


def reconstruction_job_repository_from(request: Request) -> ReconstructionJobRepository:
    repository = getattr(request.app.state, "reconstruction_job_repository", None)
    if repository is not None:
        return repository

    repository = OracleReconstructionJobRepository(settings)
    request.app.state.reconstruction_job_repository = repository
    return repository


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


@router.get("/jobs")
def admin_jobs(
    request: Request,
    status: str | None = None,
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
) -> dict[str, object]:
    try:
        authorize_admin_request(request, credentials)
    except AuthErrorResponse as exc:
        return exc.response

    if status is not None and status not in ALLOWED_RECONSTRUCTION_STATUSES:
        return error_response(
            code="validation_error",
            message="Invalid reconstruction job status.",
            status_code=422,
            request_id=request_id_from(request),
        )

    jobs = reconstruction_job_repository_from(request).list_for_admin(status=status)
    return {
        "data": {
            "jobs": [
                reconstruction_job_response_from(job).model_dump() for job in jobs
            ],
            "allowed_statuses": list(ALLOWED_ADMIN_JOB_STATUSES),
        },
        "error": None,
        "meta": {"request_id": request_id_from(request)},
    }
