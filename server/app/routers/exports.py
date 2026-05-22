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
    OracleLayoutRepository,
)
from app.repositories.projects import ProjectNotFound

router = APIRouter(prefix="/room-projects", tags=["exports"])


def layout_repository_from(request: Request) -> LayoutRepository:
    repository = getattr(request.app.state, "layout_repository", None)
    if repository is not None:
        return repository

    repository = OracleLayoutRepository(settings)
    request.app.state.layout_repository = repository
    return repository


@router.get("/{project_id}/layouts/latest/export")
def export_latest_layout(
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

    return export_envelope(request, layout)


@router.get("/{project_id}/layouts/{layout_id}/export")
def export_layout(
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

    return export_envelope(request, layout)


def export_envelope(request: Request, layout: LayoutRecord) -> dict[str, object]:
    return {
        "data": {
            "export": {
                "format": "roomforge_layout_json",
                "version": 1,
                "layout": {
                    "id": layout.id,
                    "project_id": layout.project_id,
                    "room_dimensions": layout.room_dimensions,
                    "floor_plan": layout.floor_plan,
                    "source_metadata": layout.source_metadata,
                    "furniture_objects": layout.furniture_objects,
                    "editor_scene": layout.editor_scene,
                    "created_at": layout.created_at.isoformat(),
                    "updated_at": layout.updated_at.isoformat(),
                },
            }
        },
        "error": None,
        "meta": {"request_id": request_id_from(request)},
    }


def not_found_response(request: Request):
    return error_response(
        code="not_found",
        message="Room layout was not found.",
        status_code=404,
        request_id=request_id_from(request),
    )
