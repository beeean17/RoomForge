from datetime import datetime
from typing import Any

from pydantic import BaseModel, Field, field_validator


class OpenCvResultCreateRequest(BaseModel):
    job_id: int = Field(gt=0)
    coordinate_space: str = "image_pixels"
    candidate_geometry: dict[str, Any]
    confidence: float | None = Field(default=None, ge=0, le=1)
    algorithm: str = Field(default="roomforge-browser-opencv-stub", max_length=100)

    @field_validator("coordinate_space")
    @classmethod
    def coordinate_space_must_be_image_pixels(cls, value: str) -> str:
        if value != "image_pixels":
            raise ValueError("OpenCV candidates must use image_pixels coordinate space.")
        return value


class OpenCvResultResponse(BaseModel):
    id: int
    project_id: int
    user_id: int
    job_id: int
    coordinate_space: str
    candidate_geometry: dict[str, Any]
    confidence: float | None
    algorithm: str
    created_at: datetime


class OpenCvResultData(BaseModel):
    opencv_result: OpenCvResultResponse
