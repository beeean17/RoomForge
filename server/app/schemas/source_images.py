from datetime import datetime

from pydantic import BaseModel, Field, field_validator


class SourceImageUploadRequest(BaseModel):
    filename: str = Field(min_length=1, max_length=255)
    content_type: str = Field(min_length=1, max_length=100)
    byte_size: int = Field(gt=0)
    image_base64: str = Field(min_length=1)
    width_px: int | None = Field(default=None, gt=0)
    height_px: int | None = Field(default=None, gt=0)

    @field_validator("filename")
    @classmethod
    def filename_must_not_be_blank(cls, value: str) -> str:
        if not value.strip():
            raise ValueError("Filename must not be blank.")
        return value


class SourceImageResponse(BaseModel):
    id: int
    project_id: int
    user_id: int
    original_filename: str
    stored_name: str
    content_type: str
    byte_size: int
    width_px: int | None
    height_px: int | None
    sha256_hex: str
    retention_status: str
    uploaded_at: datetime


class SourceImageData(BaseModel):
    source_image: SourceImageResponse
