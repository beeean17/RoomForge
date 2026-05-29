from fastapi import APIRouter, Depends, Request
from fastapi.security import HTTPAuthorizationCredentials
import oracledb

from app.auth.dependencies import (
    AuthErrorResponse,
    authorize_admin_request,
    bearer_scheme,
)
from app.core.config import settings
from app.core.errors import error_response
from app.core.request import request_id_from
from app.repositories.confirmed_geometries import (
    ConfirmedGeometryRepository,
    OracleConfirmedGeometryRepository,
)
from app.repositories.floor_plans import FloorPlanRepository, OracleFloorPlanRepository
from app.repositories.opencv_results import (
    OpenCvResultNotFound,
    OpenCvResultRepository,
    OracleOpenCvResultRepository,
)
from app.repositories.reconstruction_jobs import (
    ALLOWED_RECONSTRUCTION_STATUSES,
    OracleReconstructionJobRepository,
    ReconstructionJobNotFound,
    ReconstructionJobRepository,
)
from app.routers.reconstruction_jobs import (
    reconstruction_job_response_from,
    reconstruction_job_transition_response_from,
    status_label_for,
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


def opencv_result_repository_from(request: Request) -> OpenCvResultRepository:
    repository = getattr(request.app.state, "opencv_result_repository", None)
    if repository is not None:
        return repository
    repository = OracleOpenCvResultRepository(settings)
    request.app.state.opencv_result_repository = repository
    return repository


def confirmed_geometry_repository_from(
    request: Request,
) -> ConfirmedGeometryRepository:
    repository = getattr(request.app.state, "confirmed_geometry_repository", None)
    if repository is not None:
        return repository
    repository = OracleConfirmedGeometryRepository(settings)
    request.app.state.confirmed_geometry_repository = repository
    return repository


def floor_plan_repository_from(request: Request) -> FloorPlanRepository:
    repository = getattr(request.app.state, "floor_plan_repository", None)
    if repository is not None:
        return repository
    repository = OracleFloorPlanRepository(settings)
    request.app.state.floor_plan_repository = repository
    return repository


def admin_search_records(request: Request, query: str) -> list[dict[str, object]]:
    repository = getattr(request.app.state, "admin_search_repository", None)
    if repository is not None:
        return repository.search(query)

    if not query.isdigit():
        return []
    record_id = int(query)
    records: list[dict[str, object]] = []
    with oracledb.connect(
        user=settings.oracle_user,
        password=settings.oracle_password,
        dsn=settings.oracle_dsn,
    ) as connection:
        with connection.cursor() as cursor:
            cursor.execute(
                """
                SELECT id, email, display_name, firebase_uid, role
                FROM users
                WHERE id = :record_id
                """,
                record_id=record_id,
            )
            if row := cursor.fetchone():
                label = row[2] or row[1] or row[3] or f"User {int(row[0])}"
                records.append(
                    {
                        "type": "user",
                        "id": int(row[0]),
                        "label": label,
                        "context": search_context(
                            email=row[1], firebase_uid=row[3], role=row[4]
                        ),
                    }
                )

            cursor.execute(
                """
                SELECT id, name, user_id
                FROM room_projects
                WHERE id = :record_id
                """,
                record_id=record_id,
            )
            if row := cursor.fetchone():
                records.append(
                    {
                        "type": "project",
                        "id": int(row[0]),
                        "label": row[1],
                        "context": search_context(user_id=int(row[2])),
                    }
                )

            cursor.execute(
                """
                SELECT id, project_id, user_id
                FROM layouts
                WHERE id = :record_id
                """,
                record_id=record_id,
            )
            if row := cursor.fetchone():
                records.append(
                    {
                        "type": "layout",
                        "id": int(row[0]),
                        "label": f"Layout {int(row[0])}",
                        "context": search_context(
                            project_id=int(row[1]), user_id=int(row[2])
                        ),
                    }
                )

            cursor.execute(
                """
                SELECT id, status, project_id, user_id, provider, failure_reason_code
                FROM reconstruction_jobs
                WHERE id = :record_id
                """,
                record_id=record_id,
            )
            if row := cursor.fetchone():
                records.append(
                    {
                        "type": "job",
                        "id": int(row[0]),
                        "label": f"{status_label_for(str(row[1]))} reconstruction job",
                        "context": search_context(
                            status=row[1],
                            project_id=int(row[2]),
                            user_id=int(row[3]),
                            provider=row[4],
                            failure_reason_code=row[5],
                        ),
                    }
                )
    return records


def search_context(**values: object) -> dict[str, object]:
    return {key: value for key, value in values.items() if value is not None}


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


@router.get("/jobs/{job_id}/artifacts")
def admin_job_artifacts(
    job_id: int,
    request: Request,
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
) -> dict[str, object]:
    try:
        authorize_admin_request(request, credentials)
        job = reconstruction_job_repository_from(request).get_for_admin(job_id)
        opencv_result = opencv_result_repository_from(request).get_latest_for_admin_job(
            job_id
        )
        confirmed = confirmed_geometry_repository_from(
            request
        ).list_for_admin_opencv_result(opencv_result.id)
        floor_plans = [
            floor_plan
            for geometry in confirmed
            for floor_plan in floor_plan_repository_from(
                request
            ).list_for_admin_confirmed_geometry(geometry.id)
        ]
    except AuthErrorResponse as exc:
        return exc.response
    except (ReconstructionJobNotFound, OpenCvResultNotFound):
        return not_found_response(request)

    return {
        "data": {
            "job": reconstruction_job_response_from(job).model_dump(),
            "source_image": {"id": job.source_image_id, "access": "restricted"},
            "candidate": {
                "opencv_result_id": opencv_result.id,
                "coordinate_space": opencv_result.coordinate_space,
                "geometry": opencv_result.candidate_geometry,
                "confidence": opencv_result.confidence,
                "algorithm": opencv_result.algorithm,
            },
            "confirmed": [
                {
                    "id": geometry.id,
                    "coordinate_space": geometry.coordinate_space,
                    "geometry_kind": geometry.geometry_kind,
                    "points": geometry.points,
                }
                for geometry in confirmed
            ],
            "calibration": [
                {
                    "floor_plan_id": floor_plan.id,
                    "unit": floor_plan.unit,
                    "width_value": floor_plan.width_value,
                    "depth_value": floor_plan.depth_value,
                    "width_deviation_ratio": floor_plan.width_deviation_ratio,
                    "depth_deviation_ratio": floor_plan.depth_deviation_ratio,
                    "aspect_ratio_error": floor_plan.aspect_ratio_error,
                    "image_geometry": floor_plan.image_geometry,
                    "metric_geometry": floor_plan.metric_geometry,
                }
                for floor_plan in floor_plans
            ],
        },
        "error": None,
        "meta": {"request_id": request_id_from(request)},
    }


@router.post("/jobs/{job_id}/retry", status_code=201)
def admin_retry_job(
    job_id: int,
    request: Request,
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
) -> dict[str, object]:
    try:
        authorize_admin_request(request, credentials)
        repository = reconstruction_job_repository_from(request)
        original = repository.get_for_admin(job_id)
        if original.status not in {"failed", "timeout"}:
            return error_response(
                code="retry_unavailable",
                message="Retry is only available for failed or timed-out jobs.",
                status_code=409,
                request_id=request_id_from(request),
            )
        retry = repository.retry_for_admin(job_id)
        transitions = repository.list_transitions_for_admin(retry.id)
    except AuthErrorResponse as exc:
        return exc.response
    except ReconstructionJobNotFound:
        return not_found_response(request)

    return {
        "data": {
            "job": reconstruction_job_response_from(retry).model_dump(),
            "transitions": [
                reconstruction_job_transition_response_from(transition).model_dump()
                for transition in transitions
            ],
            "retry_count": 0,
            "retry_of_job_id": job_id,
        },
        "error": None,
        "meta": {"request_id": request_id_from(request)},
    }


@router.get("/search")
def admin_search(
    request: Request,
    q: str,
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
) -> dict[str, object]:
    try:
        authorize_admin_request(request, credentials)
    except AuthErrorResponse as exc:
        return exc.response

    query = q.strip()
    if not query:
        return error_response(
            code="validation_error",
            message="Search query is required.",
            status_code=422,
            request_id=request_id_from(request),
        )

    return {
        "data": {"query": query, "results": admin_search_records(request, query)},
        "error": None,
        "meta": {"request_id": request_id_from(request)},
    }


@router.get("/jobs/{job_id}/diagnosis")
def admin_job_diagnosis(
    job_id: int,
    request: Request,
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
) -> dict[str, object]:
    try:
        authorize_admin_request(request, credentials)
        job = reconstruction_job_repository_from(request).get_for_admin(job_id)
    except AuthErrorResponse as exc:
        return exc.response
    except ReconstructionJobNotFound:
        return not_found_response(request)

    return {
        "data": {
            "job": reconstruction_job_response_from(job).model_dump(),
            "provider_state": {
                "provider": job.provider,
                "status": job.status,
                "retry_of_job_id": job.retry_of_job_id,
                "failure_reason_code": job.failure_reason_code,
                "failure_reason_message": job.failure_reason_message,
            },
            "failure_source": failure_source_for(job.failure_reason_code),
        },
        "error": None,
        "meta": {"request_id": request_id_from(request)},
    }


def failure_source_for(reason_code: str | None) -> dict[str, object]:
    code = (reason_code or "").lower()
    if any(token in code for token in ("input", "photo", "image")):
        source = "input_quality"
    elif any(token in code for token in ("opencv", "candidate", "detection", "confidence")):
        source = "opencv_candidate_detection"
    elif any(token in code for token in ("calibration", "scale", "geometry")):
        source = "user_calibration"
    elif any(token in code for token in ("api", "validation", "request")):
        source = "api_handling"
    elif any(token in code for token in ("db", "database", "oracle")):
        source = "database_state"
    else:
        source = "provider_processing"
    return {
        "source": source,
        "reason_code": reason_code,
        "supported_sources": [
            "input_quality",
            "opencv_candidate_detection",
            "user_calibration",
            "api_handling",
            "database_state",
            "provider_processing",
        ],
    }


def not_found_response(request: Request):
    return error_response(
        code="not_found",
        message="Reconstruction job was not found.",
        status_code=404,
        request_id=request_id_from(request),
    )
