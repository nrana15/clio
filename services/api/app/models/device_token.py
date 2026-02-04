"""
Device token model for push notifications
"""
import uuid
from datetime import datetime

from sqlalchemy import Column, String, DateTime, ForeignKey, Index
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func

from app.db.session import Base


class DeviceToken(Base):
    """FCM device tokens for push notifications."""
    __tablename__ = "device_tokens"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    
    # Device info
    token = Column(String(500), nullable=False, unique=True, index=True)
    platform = Column(String(20), nullable=False)  # ios, android
    device_name = Column(String(200), nullable=True)
    device_model = Column(String(100), nullable=True)
    app_version = Column(String(50), nullable=True)
    
    # Status
    is_active = Column(String(10), default="active")  # active, inactive
    
    # Timestamps
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    last_used_at = Column(DateTime(timezone=True), nullable=True)
    
    # Relationships
    user = relationship("User")
    
    __table_args__ = (
        Index('idx_device_tokens_user_active', 'user_id', 'is_active'),
    )
    
    def __repr__(self):
        return f"<DeviceToken {self.platform} {self.device_model}>"


class NotificationLog(Base):
    """Log of sent notifications for analytics and debugging."""
    __tablename__ = "notification_logs"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    
    # Notification details
    notification_type = Column(String(50), nullable=False)  # due_soon, due_today, overdue
    title = Column(String(200), nullable=False)
    body = Column(String(500), nullable=False)
    
    # Target
    device_token_id = Column(UUID(as_uuid=True), ForeignKey("device_tokens.id"), nullable=True)
    
    # Status
    status = Column(String(20), nullable=False)  # sent, delivered, failed, bounced
    error_message = Column(String(500), nullable=True)
    
    # FCM response
    fcm_message_id = Column(String(200), nullable=True)
    
    # Timestamps
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    delivered_at = Column(DateTime(timezone=True), nullable=True)
    
    # Relationships
    user = relationship("User")
    device_token = relationship("DeviceToken")
    
    def __repr__(self):
        return f"<NotificationLog {self.notification_type} {self.status}>"
