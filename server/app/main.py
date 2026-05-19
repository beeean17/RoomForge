from fastapi import FastAPI
from fastapi.exceptions import RequestValidationError

from app.core.errors import error_response
from app.core.request import request_id_from
from app.routers import (
    admin,
    auth,
    dimensions,
    health,
    projects,
    reconstruction_jobs,
    source_images,
)


def create_app() -> FastAPI:
    app = FastAPI(title="RoomForge API", version="0.1.0")

    @app.exception_handler(RequestValidationError)
    async def validation_exception_handler(request, exc):
        return error_response(
            code="validation_error",
            message="Request validation failed.",
            status_code=422,
            request_id=request_id_from(request),
        )

    app.include_router(auth.router)
    app.include_router(admin.router)
    app.include_router(projects.router)
    app.include_router(source_images.router)
    app.include_router(dimensions.router)
    app.include_router(reconstruction_jobs.router)
    app.include_router(health.router)
    return app


app = create_app()
