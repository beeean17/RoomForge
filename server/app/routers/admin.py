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
    ReconstructionJobNotFound,
    ReconstructionJobRepository,
)
from app.routers.reconstruction_jobs import (
    reconstruction_job_response_from,
    reconstruction_job_transition_response_from,
)
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


@router.get("/jobs/{job_id}")
def admin_job_detail(
    job_id: int,
    request: Request,
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
) -> dict[str, object]:
    try:
        authorize_admin_request(request, credentials)
        repository = reconstruction_job_repository_from(request)
        job = repository.get_for_admin(job_id)
        transitions = repository.list_transitions_for_admin(job_id)
        retry_count = repository.count_retries_for_admin(job_id)
    except AuthErrorResponse as exc:
        return exc.response
    except ReconstructionJobNotFound:
        return not_found_response(request)

    return {
        "data": {
            "job": reconstruction_job_response_from(job).model_dump(),
            "retry_count": retry_count,
            "transitions": [
                reconstruction_job_transition_response_from(transition).model_dump()
                for transition in transitions
            ],
        },
        "error": None,
        "meta": {"request_id": request_id_from(request)},
    }


def not_found_response(request: Request):
    return error_response(
        code="not_found",
        message="Reconstruction job was not found.",
        status_code=404,
        request_id=request_id_from(request),
    )
