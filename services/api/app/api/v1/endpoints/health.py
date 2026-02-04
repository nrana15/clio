"""
Health check endpoints
"""
from fastapi import APIRouter

router = APIRouter()


@router.get("/")
async def health():
    """Health check."""
    return {"status": "ok"}
