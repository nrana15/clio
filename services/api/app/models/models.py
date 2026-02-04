"""
Database models for CLIO
"""
import uuid
from datetime import datetime, date
from enum import Enum as PyEnum
from typing import Optional

from sqlalchemy import (
    Column, String, DateTime, Date, Numeric, Integer, 
    ForeignKey, Index, Text, Boolean, Enum, CheckConstraint
)
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func

from app.db.session import Base


class BillStatus(str, PyEnum):
    PENDING_REVIEW = "pending_review"
    UNPAID = "unpaid"
    PAID_CONFIRMED = "paid_confirmed"


class User(Base):
    """User account model."""
    __tablename__ = "users"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    phone_number = Column(String(20), unique=True, nullable=True, index=True)
    email = Column(String(255), unique=True, nullable=True, index=True)
    
    # Profile
    full_name = Column(String(255), nullable=True)
    
    # Security
    hashed_password = Column(String(255), nullable=True)  # For future password auth
    is_active = Column(Boolean, default=True)
    is_verified = Column(Boolean, default=False)
    
    # Settings
    preferred_language = Column(String(10), default="zh-TW")
    enable_biometric_lock = Column(Boolean, default=False)
    enable_push_notifications = Column(Boolean, default=True)
    
    # Timestamps
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    last_login_at = Column(DateTime(timezone=True), nullable=True)
    
    # Relationships
    cards = relationship("Card", back_populates="user", cascade="all, delete-orphan")
    bills = relationship("Bill", back_populates="user", cascade="all, delete-orphan")
    audit_logs = relationship("AuditLog", back_populates="user")
    
    def __repr__(self):
        return f"<User {self.id}>"


class Card(Base):
    """Credit card model - stores only non-sensitive data."""
    __tablename__ = "cards"
    
    __table_args__ = (
        CheckConstraint("length(last_four) = 4", name="check_last_four_length"),
    )
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    
    # Card info (non-sensitive only)
    issuer_bank = Column(String(100), nullable=False)  # CTBC, Cathay, Taishin, etc.
    last_four = Column(String(4), nullable=False)  # Last 4 digits only
    nickname = Column(String(100), nullable=True)
    
    # Display
    card_color = Column(String(7), nullable=True)  # Hex color for UI
    
    # Status
    is_active = Column(Boolean, default=True)
    
    # Timestamps
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    # Relationships
    user = relationship("User", back_populates="cards")
    bills = relationship("Bill", back_populates="card")
    
    def __repr__(self):
        return f"<Card {self.issuer_bank} ****{self.last_four}>"
    
    @property
    def display_name(self) -> str:
        if self.nickname:
            return f"{self.nickname} ({self.issuer_bank} ****{self.last_four})"
        return f"{self.issuer_bank} ****{self.last_four}"


class SourceArtifact(Base):
    """Uploaded statement file (PDF, image)."""
    __tablename__ = "source_artifacts"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    
    # File info
    original_filename = Column(String(500), nullable=False)
    storage_key = Column(String(500), nullable=False, unique=True)  # MinIO/S3 key
    mime_type = Column(String(100), nullable=False)
    file_size_bytes = Column(Integer, nullable=False)
    
    # Processing
    processing_status = Column(String(50), default="pending")  # pending, processing, completed, failed
    processing_error = Column(Text, nullable=True)
    
    # Security
    checksum_sha256 = Column(String(64), nullable=True)
    
    # Retention
    uploaded_at = Column(DateTime(timezone=True), server_default=func.now())
    delete_after = Column(DateTime(timezone=True), nullable=False)  # Retention deadline
    deleted_at = Column(DateTime(timezone=True), nullable=True)
    
    # Relationships
    user = relationship("User")
    bill = relationship("Bill", back_populates="source_artifact", uselist=False)
    
    def __repr__(self):
        return f"<SourceArtifact {self.original_filename}>"


class Bill(Base):
    """Extracted credit card bill."""
    __tablename__ = "bills"
    
    __table_args__ = (
        Index('idx_bills_user_due_date', 'user_id', 'due_date'),
        Index('idx_bills_card_statement', 'card_id', 'statement_date'),
    )
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    card_id = Column(UUID(as_uuid=True), ForeignKey("cards.id", ondelete="CASCADE"), nullable=False, index=True)
    source_artifact_id = Column(UUID(as_uuid=True), ForeignKey("source_artifacts.id"), nullable=True, unique=True)
    
    # Extracted data
    statement_date = Column(Date, nullable=False)
    statement_month = Column(String(7), nullable=False)  # YYYY-MM format
    due_date = Column(Date, nullable=False, index=True)
    
    # Amounts
    total_amount_due = Column(Numeric(15, 2), nullable=False)
    minimum_due = Column(Numeric(15, 2), nullable=True)
    currency = Column(String(3), default="TWD")
    
    # Extraction quality
    extraction_confidence = Column(Numeric(3, 2), nullable=False)  # 0.00 to 1.00
    requires_review = Column(Boolean, default=False)
    reviewed_by_user = Column(Boolean, default=False)
    review_notes = Column(Text, nullable=True)
    
    # Raw extraction data (for debugging/improvement)
    raw_extraction_data = Column(JSONB, nullable=True)
    
    # Status
    status = Column(Enum(BillStatus), default=BillStatus.PENDING_REVIEW, nullable=False)
    
    # Payment tracking
    paid_confirmed_at = Column(DateTime(timezone=True), nullable=True)
    paid_confirmed_by = Column(String(50), nullable=True)  # user, system
    
    # Timestamps
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    # Relationships
    user = relationship("User", back_populates="bills")
    card = relationship("Card", back_populates="bills")
    source_artifact = relationship("SourceArtifact", back_populates="bill")
    notification_schedules = relationship("NotificationSchedule", back_populates="bill", cascade="all, delete-orphan")
    
    def __repr__(self):
        return f"<Bill {self.card.issuer_bank if self.card else 'Unknown'} {self.statement_month}>"
    
    @property
    def is_overdue(self) -> bool:
        if self.status == BillStatus.PAID_CONFIRMED:
            return False
        return date.today() > self.due_date
    
    @property
    def days_until_due(self) -> int:
        if self.status == BillStatus.PAID_CONFIRMED:
            return float('inf')
        return (self.due_date - date.today()).days


class NotificationSchedule(Base):
    """Scheduled reminders for bills."""
    __tablename__ = "notification_schedules"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    bill_id = Column(UUID(as_uuid=True), ForeignKey("bills.id", ondelete="CASCADE"), nullable=False, index=True)
    
    # Schedule
    scheduled_at = Column(DateTime(timezone=True), nullable=False, index=True)
    notification_type = Column(String(50), nullable=False)  # due_soon, due_today, overdue
    
    # Status
    sent_at = Column(DateTime(timezone=True), nullable=True)
    send_status = Column(String(50), default="pending")  # pending, sent, failed, cancelled
    error_message = Column(Text, nullable=True)
    
    # Timestamps
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    # Relationships
    user = relationship("User")
    bill = relationship("Bill", back_populates="notification_schedules")
    
    def __repr__(self):
        return f"<NotificationSchedule {self.notification_type} {self.scheduled_at}>"


class AuditLog(Base):
    """Audit trail for security and compliance."""
    __tablename__ = "audit_logs"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True)
    
    # Action details
    action = Column(String(100), nullable=False, index=True)  # bill_created, bill_updated, bill_paid, etc.
    resource_type = Column(String(50), nullable=False)  # bill, card, user
    resource_id = Column(UUID(as_uuid=True), nullable=True)
    
    # Request context (PII scrubbed)
    ip_address = Column(String(45), nullable=True)  # IPv6 compatible
    user_agent = Column(String(500), nullable=True)
    request_id = Column(String(100), nullable=True, index=True)
    
    # Action payload (sanitized - no PII, no statement content)
    meta_data = Column(JSONB, nullable=True)
    
    # Timestamp
    created_at = Column(DateTime(timezone=True), server_default=func.now(), index=True)
    
    # Retention
    delete_after = Column(DateTime(timezone=True), nullable=False)
    
    # Relationships
    user = relationship("User", back_populates="audit_logs")
    
    def __repr__(self):
        return f"<AuditLog {self.action} {self.resource_type}>"


class OTPAttempt(Base):
    """OTP verification attempts."""
    __tablename__ = "otp_attempts"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    
    # Target
    phone_number = Column(String(20), nullable=True, index=True)
    email = Column(String(255), nullable=True, index=True)
    
    # OTP details
    otp_code = Column(String(10), nullable=False)
    expires_at = Column(DateTime(timezone=True), nullable=False)
    
    # Status
    verified = Column(Boolean, default=False)
    verified_at = Column(DateTime(timezone=True), nullable=True)
    attempts_count = Column(Integer, default=0)
    
    # Request context
    ip_address = Column(String(45), nullable=True)
    
    # Timestamps
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    def __repr__(self):
        return f"<OTPAttempt {self.phone_number or self.email}>"
