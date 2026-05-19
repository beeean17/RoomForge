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
from app.repositories.confirmed_geometries import ConfirmedGeometryNotFound
from app.repositories.floor_plans import (
    FloorPlanCreate,
    FloorPlanNotFound,
    FloorPlanRecord,
    FloorPlanRepository,
    OracleFloorPlanRepository,
)
from app.schemas.floor_plans import FloorPlanCreateRequest, FloorPlanResponse

router = APIRouter(prefix="/room-projects", tags=["floor-plans"])


def floor_plan_repository_from(request: Request) -> FloorPlanRepository:
    repository = getattr(request.app.state, "floor_plan_repository", None)
    if repository is not None:
        return repository

    repository = OracleFloorPlanRepository(settings)
    request.app.state.floor_plan_repository = repository
    return repository


@router.post("/{project_id}/floor-plans", status_code=201)
def create_floor_plan(
    project_id: int,
    payload: FloorPlanCreateRequest,
    request: Request,
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
) -> dict[str, object]:
    try:
        user = authenticate_request(request, credentials)
        floor_plan = floor_plan_repository_from(request).create_for_project(
            user,
            project_id,
            FloorPlanCreate(
                confirmed_geometry_id=payload.confirmed_geometry_id,
                reference_line=payload.reference_line,
                reference_length_value=payload.reference_length_value,
                unit=payload.unit,
            ),
        )
    except AuthErrorResponse as exc:
        return exc.response
    except ConfirmedGeometryNotFound:
        return not_found_response(request)

    return floor_plan_envelope(request, floor_plan)


@router.get("/{project_id}/floor-plans/{floor_plan_id}")
def get_floor_plan(
    project_id: int,
    floor_plan_id: int,
    request: Request,
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
) -> dict[str, object]:
    try:
        user = authenticate_request(request, credentials)
        floor_plan = floor_plan_repository_from(request).get_for_project(
            user,
            project_id,
            floor_plan_id,
        )
    except AuthErrorResponse as exc:
        return exc.response
    except FloorPlanNotFound:
        return not_found_response(request)

    return floor_plan_envelope(request, floor_plan)


def floor_plan_envelope(request: Request, floor_plan: FloorPlanRecord) -> dict[str, object]:
    return {
        "data": {"floor_plan": floor_plan_response_from(floor_plan).model_dump()},
        "error": None,
        "meta": {"request_id": request_id_from(request)},
    }


def floor_plan_response_from(floor_plan: FloorPlanRecord) -> FloorPlanResponse:
    return FloorPlanResponse(
        id=floor_plan.id,
        project_id=floor_plan.project_id,
        user_id=floor_plan.user_id,
        confirmed_geometry_id=floor_plan.confirmed_geometry_id,
        unit=floor_plan.unit,
        width_value=floor_plan.width_value,
        depth_value=floor_plan.depth_value,
        width_deviation_ratio=floor_plan.width_deviation_ratio,
        depth_deviation_ratio=floor_plan.depth_deviation_ratio,
        aspect_ratio_error=floor_plan.aspect_ratio_error,
        perspective_assumptions=floor_plan.perspective_assumptions,
        image_geometry=floor_plan.image_geometry,
        metric_geometry=floor_plan.metric_geometry,
        created_at=floor_plan.created_at,
    )


def not_found_response(request: Request):
    return error_response(
        code="not_found",
        message="Floor plan was not found.",
        status_code=404,
        request_id=request_id_from(request),
    )
