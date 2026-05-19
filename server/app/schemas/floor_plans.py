from datetime import datetime
from typing import Any

from pydantic import BaseModel, Field, field_validator


class FloorPlanCreateRequest(BaseModel):
    confirmed_geometry_id: int = Field(gt=0)
    reference_line: dict[str, Any]
    reference_length_value: float = Field(gt=0)
    unit: str = "meters"

    @field_validator("unit")
    @classmethod
    def unit_must_be_meters(cls, value: str) -> str:
        if value != "meters":
            raise ValueError("Only meters are supported in the MVP.")
        return value


class FloorPlanResponse(BaseModel):
    id: int
    project_id: int
    user_id: int
    confirmed_geometry_id: int
    unit: str
    width_value: float
    depth_value: float
    width_deviation_ratio: float
    depth_deviation_ratio: float
    aspect_ratio_error: float
    perspective_assumptions: dict[str, Any]
    image_geometry: dict[str, Any]
    metric_geometry: dict[str, Any]
    created_at: datetime


class FloorPlanData(BaseModel):
    floor_plan: FloorPlanResponse
