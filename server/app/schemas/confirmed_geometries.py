from datetime import datetime

from pydantic import BaseModel, Field, field_validator, model_validator


class GeometryPoint(BaseModel):
    x: float
    y: float


class ConfirmedGeometryCreateRequest(BaseModel):
    opencv_result_id: int | None = Field(default=None, gt=0)
    coordinate_space: str = "image_pixels"
    geometry_kind: str = "room_boundary"
    points: list[GeometryPoint] = Field(min_length=3)

    @field_validator("coordinate_space")
    @classmethod
    def coordinate_space_must_be_image_pixels(cls, value: str) -> str:
        if value != "image_pixels":
            raise ValueError("Confirmed pre-calibration geometry must use image_pixels.")
        return value

    @field_validator("geometry_kind")
    @classmethod
    def geometry_kind_must_be_room_boundary(cls, value: str) -> str:
        if value != "room_boundary":
            raise ValueError("Only room_boundary geometry is supported in the MVP.")
        return value

    @model_validator(mode="after")
    def geometry_must_not_self_intersect(self):
        points = [(point.x, point.y) for point in self.points]
        if polygon_self_intersects(points):
            raise ValueError("Confirmed geometry must not self-intersect.")
        return self


class ConfirmedGeometryResponse(BaseModel):
    id: int
    project_id: int
    user_id: int
    opencv_result_id: int | None
    coordinate_space: str
    geometry_kind: str
    points: list[GeometryPoint]
    created_at: datetime
    updated_at: datetime


class ConfirmedGeometryData(BaseModel):
    confirmed_geometry: ConfirmedGeometryResponse


def polygon_self_intersects(points: list[tuple[float, float]]) -> bool:
    edges = [
        (points[index], points[(index + 1) % len(points)])
        for index in range(len(points))
    ]
    for first_index, first_edge in enumerate(edges):
        for second_index, second_edge in enumerate(edges):
            if abs(first_index - second_index) <= 1:
                continue
            if first_index == 0 and second_index == len(edges) - 1:
                continue
            if segments_intersect(first_edge[0], first_edge[1], second_edge[0], second_edge[1]):
                return True
    return False


def segments_intersect(
    a: tuple[float, float],
    b: tuple[float, float],
    c: tuple[float, float],
    d: tuple[float, float],
) -> bool:
    def orientation(
        p: tuple[float, float],
        q: tuple[float, float],
        r: tuple[float, float],
    ) -> float:
        return (q[1] - p[1]) * (r[0] - q[0]) - (q[0] - p[0]) * (r[1] - q[1])

    o1 = orientation(a, b, c)
    o2 = orientation(a, b, d)
    o3 = orientation(c, d, a)
    o4 = orientation(c, d, b)
    return (o1 > 0) != (o2 > 0) and (o3 > 0) != (o4 > 0)
