from datetime import datetime
from typing import Any

from pydantic import BaseModel, Field


def _is_none(value: object) -> bool:
    return value is None


class FurnitureObjectPayload(BaseModel):
    id: str = Field(min_length=1)
    category: str = Field(min_length=1)
    position: dict[str, Any]
    size: dict[str, Any]
    rotation_degrees: float
    color: str = Field(min_length=1)
    asset_id: str | None = Field(default=None, min_length=1, exclude_if=_is_none)
    candidate_id: str | None = Field(default=None, min_length=1, exclude_if=_is_none)
    source: str | None = Field(default=None, min_length=1, exclude_if=_is_none)
    label: str | None = Field(default=None, min_length=1, exclude_if=_is_none)
    locked: bool | None = Field(default=None, exclude_if=_is_none)
    model_metadata: dict[str, Any] | None = Field(default=None, exclude_if=_is_none)


class LayoutSaveRequest(BaseModel):
    room_dimensions: dict[str, Any]
    floor_plan: dict[str, Any]
    source_metadata: dict[str, Any]
    furniture_objects: list[FurnitureObjectPayload]
    editor_scene: dict[str, Any] = Field(default_factory=dict)


class LayoutResponse(BaseModel):
    id: int
    project_id: int
    user_id: int
    room_dimensions: dict[str, Any]
    floor_plan: dict[str, Any]
    source_metadata: dict[str, Any]
    furniture_objects: list[FurnitureObjectPayload]
    editor_scene: dict[str, Any]
    created_at: datetime
    updated_at: datetime
