"""
Push notification endpoints
"""
from typing import Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_

from app.db.session import get_db
from app.models.models import User
from app.models.device_token import DeviceToken, NotificationLog
from app.schemas.notifications import (
    DeviceTokenRegister, DeviceTokenResponse, DeviceTokenListResponse,
    DeviceTokenUpdate, NotificationLogListResponse
)
from app.core.security import get_current_active_user

router = APIRouter()


@router.post(
    "/register-device",
    response_model=DeviceTokenResponse,
    summary="Register device for push notifications",
    description="Register a device token to receive push notifications via FCM."
)
async def register_device(
    token_data: DeviceTokenRegister,
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Register a device token for push notifications."""
    # Check if token already exists
    query = select(DeviceToken).where(DeviceToken.token == token_data.token)
    result = await db.execute(query)
    existing = result.scalar_one_or_none()
    
    if existing:
        # Update existing token
        existing.user_id = user.id
        existing.platform = token_data.platform
        existing.device_name = token_data.device_name
        existing.device_model = token_data.device_model
        existing.app_version = token_data.app_version
        existing.is_active = "active"
        existing.last_used_at = datetime.utcnow()
        
        await db.commit()
        await db.refresh(existing)
        return existing
    
    # Create new device token
    device = DeviceToken(
        user_id=user.id,
        token=token_data.token,
        platform=token_data.platform,
        device_name=token_data.device_name,
        device_model=token_data.device_model,
        app_version=token_data.app_version,
        is_active="active",
        last_used_at=datetime.utcnow()
    )
    
    db.add(device)
    await db.commit()
    await db.refresh(device)
    
    return device


@router.get(
    "/devices",
    response_model=DeviceTokenListResponse,
    summary="List registered devices",
    description="Get all registered devices for push notifications."
)
async def list_devices(
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """List all registered devices for the current user."""
    query = select(DeviceToken).where(DeviceToken.user_id == user.id)
    result = await db.execute(query)
    devices = result.scalars().all()
    
    return DeviceTokenListResponse(devices=list(devices))


@router.patch(
    "/devices/{device_id}",
    response_model=DeviceTokenResponse,
    summary="Update device status",
    description="Activate or deactivate a device token."
)
async def update_device(
    device_id: UUID,
    update_data: DeviceTokenUpdate,
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Update device token status."""
    query = select(DeviceToken).where(
        and_(DeviceToken.id == device_id, DeviceToken.user_id == user.id)
    )
    result = await db.execute(query)
    device = result.scalar_one_or_none()
    
    if not device:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Device not found"
        )
    
    device.is_active = update_data.is_active
    await db.commit()
    await db.refresh(device)
    
    return device


@router.delete(
    "/devices/{device_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Unregister device",
    description="Remove a device token."
)
async def unregister_device(
    device_id: UUID,
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Unregister a device token."""
    query = select(DeviceToken).where(
        and_(DeviceToken.id == device_id, DeviceToken.user_id == user.id)
    )
    result = await db.execute(query)
    device = result.scalar_one_or_none()
    
    if not device:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Device not found"
        )
    
    await db.delete(device)
    await db.commit()
    
    return None


@router.get(
    "/history",
    response_model=NotificationLogListResponse,
    summary="Get notification history",
    description="Get history of sent notifications."
)
async def get_notification_history(
    limit: int = Query(50, ge=1, le=100),
    offset: int = Query(0, ge=0),
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Get notification history for the current user."""
    query = select(NotificationLog).where(
        NotificationLog.user_id == user.id
    ).order_by(NotificationLog.created_at.desc()).limit(limit).offset(offset)
    
    result = await db.execute(query)
    notifications = result.scalars().all()
    
    # Get total count
    count_query = select(func.count(NotificationLog.id)).where(
        NotificationLog.user_id == user.id
    )
    count_result = await db.execute(count_query)
    total = count_result.scalar()
    
    return NotificationLogListResponse(
        notifications=list(notifications),
        total=total
    )


from datetime import datetime
from sqlalchemy import func
