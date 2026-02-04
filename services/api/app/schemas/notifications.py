"""
Notification schemas
"""
from datetime import datetime
from typing import Optional
from uuid import UUID

from pydantic import BaseModel, Field, ConfigDict


# ============================================
# Device Token Schemas
# ============================================

class DeviceTokenRegister(BaseModel):
    """Register a device token for push notifications."""
    token: str = Field(..., min_length=100, max_length=500)
    platform: str = Field(..., pattern=r'^(ios|android)$')
    device_name: Optional[str] = Field(None, max_length=200)
    device_model: Optional[str] = Field(None, max_length=100)
    app_version: Optional[str] = Field(None, max_length=50)


class DeviceTokenResponse(BaseModel):
    """Device token response."""
    model_config = ConfigDict(from_attributes=True)
    
    id: UUID
    token: str
    platform: str
    device_name: Optional[str] = None
    device_model: Optional[str] = None
    app_version: Optional[str] = None
    is_active: str
    created_at: datetime
    last_used_at: Optional[datetime] = None


class DeviceTokenListResponse(BaseModel):
    """List of device tokens."""
    devices: list[DeviceTokenResponse]


class DeviceTokenUpdate(BaseModel):
    """Update device token status."""
    is_active: str = Field(..., pattern=r'^(active|inactive)$')


# ============================================
# Push Notification Schemas
# ============================================

class PushNotificationPayload(BaseModel):
    """Payload for sending a push notification."""
    title: str = Field(..., max_length=200)
    body: str = Field(..., max_length=500)
    data: Optional[dict] = None
    notification_type: str = Field(..., pattern=r'^(due_soon|due_today|overdue|general)$')


class PushNotificationResponse(BaseModel):
    """Push notification send response."""
    success: bool
    message_id: Optional[str] = None
    error: Optional[str] = None


class NotificationLogResponse(BaseModel):
    """Notification log entry response."""
    model_config = ConfigDict(from_attributes=True)
    
    id: UUID
    notification_type: str
    title: str
    body: str
    status: str
    created_at: datetime
    delivered_at: Optional[datetime] = None


class NotificationLogListResponse(BaseModel):
    """List of notification logs."""
    notifications: list[NotificationLogResponse]
    total: int
