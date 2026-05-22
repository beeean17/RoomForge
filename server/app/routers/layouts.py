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
from app.repositories.layouts import (
    LayoutNotFound,
    LayoutRecord,
    LayoutRepository,
    LayoutSave,
    OracleLayoutRepository,
)
from app.repositories.projects import ProjectNotFound
from app.schemas.layouts import LayoutResponse, LayoutSaveRequest

router = APIRouter(prefix="/room-projects", tags=["layouts"])


def layout_repository_from(request: Request) -> LayoutRepository:
    repository = getattr(request.app.state, "layout_repository", None)
    if repository is not None:
        return repository

    repository = OracleLayoutRepository(settings)
    request.app.state.layout_repository = repository
    return repository


@router.post("/{project_id}/layouts", status_code=201)
def save_layout(
    project_id: int,
    payload: LayoutSaveRequest,
    request: Request,
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
) -> dict[str, object]:
    try:
        user = authenticate_request(request, credentials)
        layout = layout_repository_from(request).save_for_project(
            user,
            project_id,
            LayoutSave(
                room_dimensions=payload.room_dimensions,
                floor_plan=payload.floor_plan,
                source_metadata=payload.source_metadata,
                furniture_objects=[
                    furniture.model_dump() for furniture in payload.furniture_objects
                ],
                editor_scene=payload.editor_scene,
            ),
        )
    except AuthErrorResponse as exc:
        return exc.response
    except ProjectNotFound:
        return not_found_response(request)

    return layout_envelope(request, layout)


@router.get("/{project_id}/layouts/latest")
def get_latest_layout(
    project_id: int,
    request: Request,
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
) -> dict[str, object]:
    try:
        user = authenticate_request(request, credentials)
        layout = layout_repository_from(request).get_latest_for_project(
            user,
            project_id,
        )
    except AuthErrorResponse as exc:
        return exc.response
    except (LayoutNotFound, ProjectNotFound):
        return not_found_response(request)

    return layout_envelope(request, layout)


@router.get("/{project_id}/layouts/{layout_id}")
def get_layout(
    project_id: int,
    layout_id: int,
    request: Request,
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
) -> dict[str, object]:
    try:
        user = authenticate_request(request, credentials)
        layout = layout_repository_from(request).get_for_project(
            user,
            project_id,
            layout_id,
        )
    except AuthErrorResponse as exc:
        return exc.response
    except (LayoutNotFound, ProjectNotFound):
        return not_found_response(request)

    return layout_envelope(request, layout)


def layout_envelope(request: Request, layout: LayoutRecord) -> dict[str, object]:
    return {
        "data": {"layout": layout_response_from(layout).model_dump()},
        "error": None,
        "meta": {"request_id": request_id_from(request)},
    }


def layout_response_from(layout: LayoutRecord) -> LayoutResponse:
    return LayoutResponse(
        id=layout.id,
        project_id=layout.project_id,
        user_id=layout.user_id,
        room_dimensions=layout.room_dimensions,
        floor_plan=layout.floor_plan,
        source_metadata=layout.source_metadata,
        furniture_objects=layout.furniture_objects,
        editor_scene=layout.editor_scene,
        created_at=layout.created_at,
        updated_at=layout.updated_at,
    )


def not_found_response(request: Request):
    return error_response(
        code="not_found",
        message="Room project was not found.",
        status_code=404,
        request_id=request_id_from(request),
    )
