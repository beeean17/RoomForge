from fastapi import APIRouter, Depends, Request
from fastapi.security import HTTPAuthorizationCredentials

from app.auth.dependencies import (
    AuthErrorResponse,
    authenticate_request,
    bearer_scheme,
)
from app.core.config import settings
from app.core.request import request_id_from
from app.repositories.projects import (
    OracleProjectRepository,
    ProjectCreate,
    ProjectRecord,
    ProjectRepository,
)
from app.schemas.projects import ProjectCreateRequest, ProjectResponse

router = APIRouter(prefix="/room-projects", tags=["room-projects"])


def project_repository_from(request: Request) -> ProjectRepository:
    repository = getattr(request.app.state, "project_repository", None)
    if repository is not None:
        return repository

    repository = OracleProjectRepository(settings)
    request.app.state.project_repository = repository
    return repository


@router.get("")
def list_projects(
    request: Request,
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
) -> dict[str, object]:
    try:
        user = authenticate_request(request, credentials)
    except AuthErrorResponse as exc:
        return exc.response

    projects = project_repository_from(request).list_for_user(user)
    return {
        "data": {
            "projects": [project_response_from(record).model_dump() for record in projects]
        },
        "error": None,
        "meta": {"request_id": request_id_from(request)},
    }


@router.post("", status_code=201)
def create_project(
    payload: ProjectCreateRequest,
    request: Request,
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
) -> dict[str, object]:
    try:
        user = authenticate_request(request, credentials)
    except AuthErrorResponse as exc:
        return exc.response

    project = project_repository_from(request).create_for_user(
        user,
        ProjectCreate(name=payload.name.strip(), description=payload.description),
    )
    return {
        "data": {"project": project_response_from(project).model_dump()},
        "error": None,
        "meta": {"request_id": request_id_from(request)},
    }


def project_response_from(record: ProjectRecord) -> ProjectResponse:
    return ProjectResponse(
        id=record.id,
        user_id=record.user_id,
        name=record.name,
        description=record.description,
        created_at=record.created_at,
        updated_at=record.updated_at,
    )
