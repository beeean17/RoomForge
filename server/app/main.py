from fastapi import FastAPI

from app.routers import admin, auth, health, projects


def create_app() -> FastAPI:
    app = FastAPI(title="RoomForge API", version="0.1.0")
    app.include_router(auth.router)
    app.include_router(admin.router)
    app.include_router(projects.router)
    app.include_router(health.router)
    return app


app = create_app()
