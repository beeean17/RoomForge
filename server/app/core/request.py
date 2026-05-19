from uuid import uuid4

from fastapi import Request


def request_id_from(request: Request) -> str:
    header_value = request.headers.get("x-request-id")
    if header_value:
        return header_value
    return f"req_{uuid4().hex}"
