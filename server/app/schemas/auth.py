from pydantic import BaseModel


class SessionUser(BaseModel):
    id: int
    firebase_uid: str
    email: str | None
    display_name: str | None
    role: str


class SessionData(BaseModel):
    user: SessionUser
