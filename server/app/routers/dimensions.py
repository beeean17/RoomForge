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
from app.repositories.dimensions import (
    OracleRoomDimensionsRepository,
    RoomDimensionsNotFound,
    RoomDimensionsRecord,
    RoomDimensionsRepository,
    RoomDimensionsUpsert,
)
from app.repositories.projects import ProjectNotFound
from app.schemas.dimensions import RoomDimensionsResponse, RoomDimensionsUpsertRequest

router = APIRouter(prefix="/room-projects", tags=["room-dimensions"])


def room_dimensions_repository_from(request: Request) -> RoomDimensionsRepository:
    repository = getattr(request.app.state, "room_dimensions_repository", None)
    if repository is not None:
        return repository

    repository = OracleRoomDimensionsRepository(settings)
    request.app.state.room_dimensions_repository = repository
    return repository


@router.get("/{project_id}/dimensions")
def get_room_dimensions(
    project_id: int,
    request: Request,
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
) -> dict[str, object]:
    try:
        user = authenticate_request(request, credentials)
        dimensions = room_dimensions_repository_from(request).get_for_project(
            user,
            project_id,
        )
    except AuthErrorResponse as exc:
        return exc.response
    except RoomDimensionsNotFound:
        return not_found_response(request)

    return {
        "data": {"dimensions": room_dimensions_response_from(dimensions).model_dump()},
        "error": None,
        "meta": {"request_id": request_id_from(request)},
    }


@router.put("/{project_id}/dimensions")
def upsert_room_dimensions(
    project_id: int,
    payload: RoomDimensionsUpsertRequest,
    request: Request,
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
) -> dict[str, object]:
    try:
        user = authenticate_request(request, credentials)
        height_source = "user"
        height_value = payload.height_value
        if height_value is None:
            height_source = "default"
            height_value = settings.room_default_height_meters

        dimensions = room_dimensions_repository_from(request).upsert_for_project(
            user,
            project_id,
            RoomDimensionsUpsert(
                width_value=payload.width_value,
                depth_value=payload.depth_value,
                height_value=height_value,
                unit=payload.unit,
                height_source=height_source,
            ),
        )
    except AuthErrorResponse as exc:
        return exc.response
    except ProjectNotFound:
        return not_found_response(request)

    return {
        "data": {"dimensions": room_dimensions_response_from(dimensions).model_dump()},
        "error": None,
        "meta": {"request_id": request_id_from(request)},
    }


def room_dimensions_response_from(record: RoomDimensionsRecord) -> RoomDimensionsResponse:
    return RoomDimensionsResponse(
        project_id=record.project_id,
        user_id=record.user_id,
        width_value=record.width_value,
        depth_value=record.depth_value,
        height_value=record.height_value,
        unit=record.unit,
        height_source=record.height_source,
        created_at=record.created_at,
        updated_at=record.updated_at,
    )


def not_found_response(request: Request):
    return error_response(
        code="not_found",
        message="Room project dimensions were not found.",
        status_code=404,
        request_id=request_id_from(request),
    )
