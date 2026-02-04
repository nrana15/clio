"""
Reminder/Notification endpoints
"""
from typing import List, Optional
from uuid import UUID
from datetime import datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_
from sqlalchemy.orm import selectinload

from app.db.session import get_db
from app.models.models import User, NotificationSchedule, Bill
from app.schemas.schemas import ReminderResponse, ReminderListResponse
from app.core.security import get_current_active_user

router = APIRouter()


@router.get(
    "",
    response_model=ReminderListResponse,
    summary="List reminders",
    description="Get all scheduled reminders for the authenticated user."
)
async def list_reminders(
    status: Optional[str] = Query(None, description="Filter by status: pending, sent, failed, cancelled"),
    upcoming_only: bool = Query(False, description="Show only upcoming reminders"),
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """List all scheduled reminders for the user."""
    query = select(NotificationSchedule).where(
        NotificationSchedule.user_id == user.id
    ).options(
        selectinload(NotificationSchedule.bill)
    )
    
    if status:
        query = query.where(NotificationSchedule.send_status == status)
    
    if upcoming_only:
        query = query.where(NotificationSchedule.scheduled_at >= datetime.utcnow())
    
    query = query.order_by(NotificationSchedule.scheduled_at.desc())
    
    result = await db.execute(query)
    reminders = result.scalars().all()
    
    return ReminderListResponse(reminders=list(reminders))


@router.get(
    "/upcoming",
    response_model=ReminderListResponse,
    summary="Get upcoming reminders",
    description="Get reminders scheduled for the next 7 days."
)
async def get_upcoming_reminders(
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Get reminders for the next 7 days."""
    now = datetime.utcnow()
    week_later = now + timedelta(days=7)
    
    query = select(NotificationSchedule).where(
        and_(
            NotificationSchedule.user_id == user.id,
            NotificationSchedule.scheduled_at >= now,
            NotificationSchedule.scheduled_at <= week_later,
            NotificationSchedule.send_status == "pending"
        )
    ).options(
        selectinload(NotificationSchedule.bill)
    ).order_by(NotificationSchedule.scheduled_at.asc())
    
    result = await db.execute(query)
    reminders = result.scalars().all()
    
    return ReminderListResponse(reminders=list(reminders))


@router.post(
    "/{reminder_id}/cancel",
    response_model=ReminderResponse,
    summary="Cancel reminder",
    description="Cancel a pending reminder."
)
async def cancel_reminder(
    reminder_id: UUID,
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Cancel a scheduled reminder."""
    query = select(NotificationSchedule).where(
        and_(
            NotificationSchedule.id == reminder_id,
            NotificationSchedule.user_id == user.id
        )
    )
    result = await db.execute(query)
    reminder = result.scalar_one_or_none()
    
    if not reminder:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Reminder not found"
        )
    
    if reminder.send_status != "pending":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Cannot cancel reminder with status: {reminder.send_status}"
        )
    
    reminder.send_status = "cancelled"
    await db.commit()
    await db.refresh(reminder)
    
    return reminder
