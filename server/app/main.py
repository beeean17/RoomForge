from fastapi import FastAPI
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware

from app.core.errors import error_response
from app.core.request import request_id_from
from app.core.config import settings
from app.repositories.memory import install_in_memory_repositories
from app.routers import (
    admin,
    auth,
    confirmed_geometries,
    dimensions,
    exports,
    floor_plans,
    health,
    layouts,
    opencv_results,
    projects,
    reconstruction_jobs,
    source_images,
)


def create_app() -> FastAPI:
    app = FastAPI(title="RoomForge API", version="0.1.0")

    if settings.use_in_memory_repositories:
        install_in_memory_repositories(app)

    app.add_middleware(
        CORSMiddleware,
        allow_origins=[
            origin.strip()
            for origin in settings.cors_allow_origins.split(",")
            if origin.strip()
        ],
        allow_origin_regex=settings.cors_allow_origin_regex or None,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

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
    app.include_router(opencv_results.router)
    app.include_router(confirmed_geometries.router)
    app.include_router(floor_plans.router)
    app.include_router(layouts.router)
    app.include_router(exports.router)
    app.include_router(health.router)
    return app


app = create_app()
