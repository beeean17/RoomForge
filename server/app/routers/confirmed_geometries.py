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
from app.repositories.confirmed_geometries import (
    ConfirmedGeometryCreate,
    ConfirmedGeometryNotFound,
    ConfirmedGeometryRecord,
    ConfirmedGeometryRepository,
    OracleConfirmedGeometryRepository,
)
from app.repositories.opencv_results import OpenCvResultNotFound
from app.schemas.confirmed_geometries import (
    ConfirmedGeometryCreateRequest,
    ConfirmedGeometryResponse,
    GeometryPoint,
)

router = APIRouter(prefix="/room-projects", tags=["confirmed-geometries"])


def confirmed_geometry_repository_from(request: Request) -> ConfirmedGeometryRepository:
    repository = getattr(request.app.state, "confirmed_geometry_repository", None)
    if repository is not None:
        return repository

    repository = OracleConfirmedGeometryRepository(settings)
    request.app.state.confirmed_geometry_repository = repository
    return repository


@router.post("/{project_id}/confirmed-geometries", status_code=201)
def create_confirmed_geometry(
    project_id: int,
    payload: ConfirmedGeometryCreateRequest,
    request: Request,
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
) -> dict[str, object]:
    try:
        user = authenticate_request(request, credentials)
        geometry = confirmed_geometry_repository_from(request).create_for_project(
            user,
            project_id,
            ConfirmedGeometryCreate(
                opencv_result_id=payload.opencv_result_id,
                coordinate_space=payload.coordinate_space,
                geometry_kind=payload.geometry_kind,
                points=[point.model_dump() for point in payload.points],
            ),
        )
    except AuthErrorResponse as exc:
        return exc.response
    except OpenCvResultNotFound:
        return not_found_response(request)

    return geometry_envelope(request, geometry)


@router.get("/{project_id}/confirmed-geometries/{geometry_id}")
def get_confirmed_geometry(
    project_id: int,
    geometry_id: int,
    request: Request,
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
) -> dict[str, object]:
    try:
        user = authenticate_request(request, credentials)
        geometry = confirmed_geometry_repository_from(request).get_for_project(
            user,
            project_id,
            geometry_id,
        )
    except AuthErrorResponse as exc:
        return exc.response
    except ConfirmedGeometryNotFound:
        return not_found_response(request)

    return geometry_envelope(request, geometry)


def geometry_envelope(
    request: Request,
    geometry: ConfirmedGeometryRecord,
) -> dict[str, object]:
    return {
        "data": {
            "confirmed_geometry": confirmed_geometry_response_from(geometry).model_dump()
        },
        "error": None,
        "meta": {"request_id": request_id_from(request)},
    }


def confirmed_geometry_response_from(
    geometry: ConfirmedGeometryRecord,
) -> ConfirmedGeometryResponse:
    return ConfirmedGeometryResponse(
        id=geometry.id,
        project_id=geometry.project_id,
        user_id=geometry.user_id,
        opencv_result_id=geometry.opencv_result_id,
        coordinate_space=geometry.coordinate_space,
        geometry_kind=geometry.geometry_kind,
        points=[GeometryPoint(**point) for point in geometry.points],
        created_at=geometry.created_at,
        updated_at=geometry.updated_at,
    )


def not_found_response(request: Request):
    return error_response(
        code="not_found",
        message="Confirmed geometry was not found.",
        status_code=404,
        request_id=request_id_from(request),
    )
