from fastapi.responses import JSONResponse


def error_response(
    *,
    code: str,
    message: str,
    status_code: int,
    request_id: str,
) -> JSONResponse:
    return JSONResponse(
        status_code=status_code,
        content={
            "data": None,
            "error": {
                "code": code,
                "message": message,
            },
            "meta": {
                "request_id": request_id,
            },
        },
    )
