"""
API Router
"""
from fastapi import APIRouter

from app.api.v1.endpoints import auth, cards, bills, uploads, reminders, health

api_router = APIRouter()

api_router.include_router(auth.router, prefix="/auth", tags=["Authentication"])
api_router.include_router(cards.router, prefix="/cards", tags=["Cards"])
api_router.include_router(bills.router, prefix="/bills", tags=["Bills"])
api_router.include_router(uploads.router, prefix="/uploads", tags=["Uploads"])
api_router.include_router(reminders.router, prefix="/reminders", tags=["Reminders"])
api_router.include_router(health.router, prefix="/health", tags=["Health"])
