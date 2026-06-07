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
from app.repositories.opencv_results import (
    OpenCvResultCreate,
    OpenCvResultNotFound,
    OpenCvResultRecord,
    OpenCvResultRepository,
    OracleOpenCvResultRepository,
)
from app.repositories.reconstruction_jobs import ReconstructionJobNotFound
from app.schemas.opencv_results import OpenCvResultCreateRequest, OpenCvResultResponse

router = APIRouter(prefix="/room-projects", tags=["opencv-results"])


def opencv_result_repository_from(request: Request) -> OpenCvResultRepository:
    repository = getattr(request.app.state, "opencv_result_repository", None)
    if repository is not None:
        return repository

    repository = OracleOpenCvResultRepository(settings)
    request.app.state.opencv_result_repository = repository
    return repository


@router.post("/{project_id}/opencv-results", status_code=201)
def create_opencv_result(
    project_id: int,
    payload: OpenCvResultCreateRequest,
    request: Request,
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
) -> dict[str, object]:
    try:
        user = authenticate_request(request, credentials)
        result = opencv_result_repository_from(request).create_for_job(
            user,
            project_id,
            OpenCvResultCreate(
                job_id=payload.job_id,
                coordinate_space=payload.coordinate_space,
                candidate_geometry=payload.candidate_geometry,
                confidence=payload.confidence,
                algorithm=payload.algorithm,
            ),
        )
    except AuthErrorResponse as exc:
        return exc.response
    except ReconstructionJobNotFound:
        return not_found_response(request)

    return result_envelope(request, result)


@router.get("/{project_id}/opencv-results/{result_id}")
def get_opencv_result(
    project_id: int,
    result_id: int,
    request: Request,
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
) -> dict[str, object]:
    try:
        user = authenticate_request(request, credentials)
        result = opencv_result_repository_from(request).get_for_project(
            user,
            project_id,
            result_id,
        )
    except AuthErrorResponse as exc:
        return exc.response
    except OpenCvResultNotFound:
        return not_found_response(request)

    return result_envelope(request, result)


def result_envelope(request: Request, result: OpenCvResultRecord) -> dict[str, object]:
    return {
        "data": {"opencv_result": opencv_result_response_from(result).model_dump()},
        "error": None,
        "meta": {"request_id": request_id_from(request)},
    }


def opencv_result_response_from(result: OpenCvResultRecord) -> OpenCvResultResponse:
    return OpenCvResultResponse(
        id=result.id,
        project_id=result.project_id,
        user_id=result.user_id,
        job_id=result.job_id,
        coordinate_space=result.coordinate_space,
        candidate_geometry=result.candidate_geometry,
        confidence=result.confidence,
        algorithm=result.algorithm,
        created_at=result.created_at,
    )


def not_found_response(request: Request):
    return error_response(
        code="not_found",
        message="OpenCV result was not found.",
        status_code=404,
        request_id=request_id_from(request),
    )
