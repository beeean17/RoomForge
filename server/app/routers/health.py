from fastapi import APIRouter

router = APIRouter(tags=["health"])


@router.get("/health")
def health_check() -> dict[str, object]:
    return {
        "data": {"status": "ok"},
        "error": None,
        "meta": {"request_id": "local-health-check"},
    }
