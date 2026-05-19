from datetime import datetime

from pydantic import BaseModel, Field, field_validator


class RoomDimensionsUpsertRequest(BaseModel):
    width_value: float = Field(gt=0, le=100)
    depth_value: float = Field(gt=0, le=100)
    height_value: float | None = Field(default=None, gt=0, le=20)
    unit: str = Field(default="meters")

    @field_validator("unit")
    @classmethod
    def unit_must_be_meters(cls, value: str) -> str:
        if value != "meters":
            raise ValueError("Only meters are supported in the MVP.")
        return value


class RoomDimensionsResponse(BaseModel):
    project_id: int
    user_id: int
    width_value: float
    depth_value: float
    height_value: float
    unit: str
    height_source: str
    created_at: datetime
    updated_at: datetime


class RoomDimensionsData(BaseModel):
    dimensions: RoomDimensionsResponse
