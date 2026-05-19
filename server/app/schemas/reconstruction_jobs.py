from datetime import datetime

from pydantic import BaseModel, Field


class ReconstructionJobCreateRequest(BaseModel):
    source_image_id: int = Field(gt=0)


class ReconstructionJobResponse(BaseModel):
    id: int
    project_id: int
    user_id: int
    source_image_id: int
    status: str
    status_label: str
    terminal: bool
    provider: str
    retry_of_job_id: int | None
    failure_reason_code: str | None
    failure_reason_message: str | None
    created_at: datetime
    updated_at: datetime


class ReconstructionJobTransitionResponse(BaseModel):
    id: int
    job_id: int
    status: str
    actor: str
    reason_code: str | None
    reason_message: str | None
    created_at: datetime


class ReconstructionJobData(BaseModel):
    job: ReconstructionJobResponse
    transitions: list[ReconstructionJobTransitionResponse]
