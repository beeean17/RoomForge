from fastapi import APIRouter, Depends, Request
from fastapi.security import HTTPAuthorizationCredentials

from app.auth.dependencies import (
    AuthErrorResponse,
    authenticate_request,
    bearer_scheme,
)
from app.core.config import settings
from app.core.errors import error_response
from app.core.request import request_id_from
from app.repositories.projects import ProjectNotFound
from app.repositories.reconstruction_jobs import (
    OracleReconstructionJobRepository,
    ReconstructionJobCreate,
    ReconstructionJobNotFound,
    ReconstructionJobRecord,
    ReconstructionJobRepository,
    ReconstructionJobTransitionRecord,
    TERMINAL_RECONSTRUCTION_STATUSES,
)
from app.schemas.reconstruction_jobs import (
    ReconstructionJobCreateRequest,
    ReconstructionJobResponse,
    ReconstructionJobTransitionResponse,
)

router = APIRouter(prefix="/room-projects", tags=["reconstruction-jobs"])


def reconstruction_job_repository_from(request: Request) -> ReconstructionJobRepository:
    repository = getattr(request.app.state, "reconstruction_job_repository", None)
    if repository is not None:
        return repository

    repository = OracleReconstructionJobRepository(settings)
    request.app.state.reconstruction_job_repository = repository
    return repository


@router.post("/{project_id}/reconstruction-jobs", status_code=201)
def create_reconstruction_job(
    project_id: int,
    payload: ReconstructionJobCreateRequest,
    request: Request,
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
) -> dict[str, object]:
    try:
        user = authenticate_request(request, credentials)
        repository = reconstruction_job_repository_from(request)
        job = repository.create_for_project(
            user,
            project_id,
            ReconstructionJobCreate(source_image_id=payload.source_image_id),
        )
        transitions = repository.list_transitions_for_job(user, project_id, job.id)
    except AuthErrorResponse as exc:
        return exc.response
    except ProjectNotFound:
        return not_found_response(request)

    return job_envelope(request, job, transitions)


@router.get("/{project_id}/reconstruction-jobs/{job_id}")
def get_reconstruction_job(
    project_id: int,
    job_id: int,
    request: Request,
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
) -> dict[str, object]:
    try:
        user = authenticate_request(request, credentials)
        repository = reconstruction_job_repository_from(request)
        job = repository.get_for_project(user, project_id, job_id)
        transitions = repository.list_transitions_for_job(user, project_id, job_id)
    except AuthErrorResponse as exc:
        return exc.response
    except ReconstructionJobNotFound:
        return not_found_response(request)

    return job_envelope(request, job, transitions)


def job_envelope(
    request: Request,
    job: ReconstructionJobRecord,
    transitions: list[ReconstructionJobTransitionRecord],
) -> dict[str, object]:
    return {
        "data": {
            "job": reconstruction_job_response_from(job).model_dump(),
            "transitions": [
                reconstruction_job_transition_response_from(transition).model_dump()
                for transition in transitions
            ],
        },
        "error": None,
        "meta": {"request_id": request_id_from(request), "poll_after_seconds": 5},
    }


def reconstruction_job_response_from(
    record: ReconstructionJobRecord,
) -> ReconstructionJobResponse:
    return ReconstructionJobResponse(
        id=record.id,
        project_id=record.project_id,
        user_id=record.user_id,
        source_image_id=record.source_image_id,
        status=record.status,
        status_label=status_label_for(record.status),
        terminal=record.status in TERMINAL_RECONSTRUCTION_STATUSES,
        provider=record.provider,
        retry_of_job_id=record.retry_of_job_id,
        failure_reason_code=record.failure_reason_code,
        failure_reason_message=record.failure_reason_message,
        created_at=record.created_at,
        updated_at=record.updated_at,
    )


def reconstruction_job_transition_response_from(
    record: ReconstructionJobTransitionRecord,
) -> ReconstructionJobTransitionResponse:
    return ReconstructionJobTransitionResponse(
        id=record.id,
        job_id=record.job_id,
        status=record.status,
        actor=record.actor,
        reason_code=record.reason_code,
        reason_message=record.reason_message,
        created_at=record.created_at,
    )


def status_label_for(status: str) -> str:
    if status == "review_required":
        return "Needs review"
    return {
        "created": "Ready",
        "uploading": "Uploading",
        "processing": "Processing",
        "succeeded": "Completed",
        "failed": "Failed",
        "timeout": "Timed out",
        "cancelled": "Cancelled",
        "retrying": "Retrying",
    }.get(status, status)


def not_found_response(request: Request):
    return error_response(
        code="not_found",
        message="Reconstruction job was not found.",
        status_code=404,
        request_id=request_id_from(request),
    )
