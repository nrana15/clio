"""
Reminder endpoints
"""
from typing import List
from datetime import datetime

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.schemas.schemas import ReminderListResponse, ReminderResponse
from app.api.v1.endpoints.cards import get_current_user

router = APIRouter()


@router.get("/upcoming", response_model=ReminderListResponse)
async def get_upcoming_reminders(
    user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Get upcoming reminders for the user."""
    # TODO: Implement reminder fetching
    return ReminderListResponse(reminders=[])
