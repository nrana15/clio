"""
Database models for the worker (synchronous version).
"""
import uuid
from datetime import datetime, date
from enum import Enum as PyEnum
from typing import Optional

from sqlalchemy import (
    Column, String, DateTime, Date, Numeric, Integer, 
    ForeignKey, Index, Text, Boolean, Enum, CheckConstraint, func
)
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.orm import relationship, declarative_base

Base = declarative_base()


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
    full_name = Column(String(255), nullable=True)
    is_active = Column(Boolean, default=True)
    preferred_language = Column(String(10), default="zh-TW")
    created_at = Column(DateTime(timezone=True), server_default=func.now())


class Card(Base):
    """Credit card model."""
    __tablename__ = "cards"
    
    __table_args__ = (
        CheckConstraint("length(last_four) = 4", name="check_last_four_length"),
    )
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    issuer_bank = Column(String(100), nullable=False)
    last_four = Column(String(4), nullable=False)
    nickname = Column(String(100), nullable=True)
    card_color = Column(String(7), nullable=True)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    user = relationship("User")
    bills = relationship("Bill", back_populates="card")


class SourceArtifact(Base):
    """Uploaded statement file."""
    __tablename__ = "source_artifacts"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    original_filename = Column(String(500), nullable=False)
    storage_key = Column(String(500), nullable=False, unique=True)
    mime_type = Column(String(100), nullable=False)
    file_size_bytes = Column(Integer, nullable=False)
    processing_status = Column(String(50), default="pending")
    processing_error = Column(Text, nullable=True)
    checksum_sha256 = Column(String(64), nullable=True)
    uploaded_at = Column(DateTime(timezone=True), server_default=func.now())
    delete_after = Column(DateTime(timezone=True), nullable=False)
    deleted_at = Column(DateTime(timezone=True), nullable=True)
    
    bill = relationship("Bill", back_populates="source_artifact", uselist=False)


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
    
    statement_date = Column(Date, nullable=False)
    statement_month = Column(String(7), nullable=False)
    due_date = Column(Date, nullable=False, index=True)
    
    total_amount_due = Column(Numeric(15, 2), nullable=False)
    minimum_due = Column(Numeric(15, 2), nullable=True)
    currency = Column(String(3), default="TWD")
    
    extraction_confidence = Column(Numeric(3, 2), nullable=False)
    requires_review = Column(Boolean, default=False)
    reviewed_by_user = Column(Boolean, default=False)
    review_notes = Column(Text, nullable=True)
    raw_extraction_data = Column(JSONB, nullable=True)
    
    status = Column(Enum(BillStatus), default=BillStatus.PENDING_REVIEW, nullable=False)
    paid_confirmed_at = Column(DateTime(timezone=True), nullable=True)
    
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    card = relationship("Card", back_populates="bills")
    source_artifact = relationship("SourceArtifact", back_populates="bill")


class AuditLog(Base):
    """Audit trail for security."""
    __tablename__ = "audit_logs"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True)
    action = Column(String(100), nullable=False, index=True)
    resource_type = Column(String(50), nullable=False)
    resource_id = Column(UUID(as_uuid=True), nullable=True)
    ip_address = Column(String(45), nullable=True)
    metadata = Column(JSONB, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), index=True)
    delete_after = Column(DateTime(timezone=True), nullable=False)
