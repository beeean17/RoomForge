import base64
import binascii
import hashlib
from uuid import uuid4

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
from app.repositories.source_images import (
    OracleSourceImageRepository,
    SourceImageCreate,
    SourceImageNotFound,
    SourceImageRecord,
    SourceImageRepository,
)
from app.schemas.source_images import SourceImageResponse, SourceImageUploadRequest

router = APIRouter(prefix="/room-projects", tags=["source-images"])


def source_image_repository_from(request: Request) -> SourceImageRepository:
    repository = getattr(request.app.state, "source_image_repository", None)
    if repository is not None:
        return repository

    repository = OracleSourceImageRepository(settings)
    request.app.state.source_image_repository = repository
    return repository


@router.post("/{project_id}/source-images", status_code=201)
def upload_source_image(
    project_id: int,
    payload: SourceImageUploadRequest,
    request: Request,
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
) -> dict[str, object]:
    try:
        user = authenticate_request(request, credentials)
    except AuthErrorResponse as exc:
        return exc.response

    validation_error = validate_upload_policy(payload, request)
    if validation_error is not None:
        return validation_error

    image_bytes = decode_image_base64(payload.image_base64)
    if image_bytes is None:
        return validation_error_response(request, "Image content must be valid base64.")
    if len(image_bytes) != payload.byte_size:
        return validation_error_response(
            request,
            "Image byte size does not match the uploaded content.",
        )

    stored_name = f"{uuid4().hex}-{payload.filename.strip()}"
    try:
        source_image = source_image_repository_from(request).create_for_project(
            user,
            project_id,
            SourceImageCreate(
                original_filename=payload.filename.strip(),
                stored_name=stored_name,
                content_type=payload.content_type,
                byte_size=payload.byte_size,
                width_px=payload.width_px,
                height_px=payload.height_px,
                sha256_hex=hashlib.sha256(image_bytes).hexdigest(),
                image_bytes=image_bytes,
            ),
        )
    except ProjectNotFound:
        return not_found_response(request)

    return {
        "data": {"source_image": source_image_response_from(source_image).model_dump()},
        "error": None,
        "meta": {"request_id": request_id_from(request)},
    }


@router.get("/{project_id}/source-images/{source_image_id}")
def get_source_image_metadata(
    project_id: int,
    source_image_id: int,
    request: Request,
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
) -> dict[str, object]:
    try:
        user = authenticate_request(request, credentials)
        source_image = source_image_repository_from(request).get_for_project(
            user,
            project_id,
            source_image_id,
        )
    except AuthErrorResponse as exc:
        return exc.response
    except SourceImageNotFound:
        return not_found_response(request)

    return {
        "data": {"source_image": source_image_response_from(source_image).model_dump()},
        "error": None,
        "meta": {"request_id": request_id_from(request)},
    }


def validate_upload_policy(payload: SourceImageUploadRequest, request: Request):
    allowed_content_types = {
        content_type.strip()
        for content_type in settings.source_image_allowed_content_types.split(",")
        if content_type.strip()
    }
    if payload.content_type not in allowed_content_types:
        return validation_error_response(
            request,
            "Supported room photo types are JPEG, PNG, and WebP.",
        )
    if payload.byte_size > settings.source_image_max_bytes:
        size_mb = settings.source_image_max_bytes / (1024 * 1024)
        return validation_error_response(
            request,
            f"Room photo must be {size_mb:g} MB or smaller.",
        )
    return None


def decode_image_base64(value: str) -> bytes | None:
    try:
        return base64.b64decode(value, validate=True)
    except (binascii.Error, ValueError):
        return None


def source_image_response_from(record: SourceImageRecord) -> SourceImageResponse:
    return SourceImageResponse(
        id=record.id,
        project_id=record.project_id,
        user_id=record.user_id,
        original_filename=record.original_filename,
        stored_name=record.stored_name,
        content_type=record.content_type,
        byte_size=record.byte_size,
        width_px=record.width_px,
        height_px=record.height_px,
        sha256_hex=record.sha256_hex,
        retention_status=record.retention_status,
        uploaded_at=record.uploaded_at,
    )


def validation_error_response(request: Request, message: str):
    return error_response(
        code="validation_error",
        message=message,
        status_code=422,
        request_id=request_id_from(request),
    )


def not_found_response(request: Request):
    return error_response(
        code="not_found",
        message="Room project or source image was not found.",
        status_code=404,
        request_id=request_id_from(request),
    )
