"""
Pydantic schemas for API request/response validation
"""
from datetime import datetime, date
from decimal import Decimal
from typing import Optional, List
from uuid import UUID

from pydantic import BaseModel, Field, ConfigDict, EmailStr


# ============================================
# Common Schemas
# ============================================

class ApiResponse(BaseModel):
    """Standard API response wrapper."""
    success: bool = True
    message: Optional[str] = None
    data: Optional[dict] = None
    request_id: Optional[str] = None


class ErrorResponse(BaseModel):
    """Standard error response."""
    success: bool = False
    error: str
    message: str
    request_id: Optional[str] = None


class PaginationParams(BaseModel):
    """Pagination query parameters."""
    page: int = Field(default=1, ge=1)
    page_size: int = Field(default=20, ge=1, le=100)


class PaginatedResponse(BaseModel):
    """Paginated response wrapper."""
    items: List[dict]
    total: int
    page: int
    page_size: int
    total_pages: int


# ============================================
# Auth Schemas
# ============================================

class AuthStartRequest(BaseModel):
    """Start authentication (send OTP)."""
    phone_number: Optional[str] = Field(None, pattern=r'^\+?[0-9]{10,15}$')
    email: Optional[EmailStr] = None
    
    model_config = ConfigDict(json_schema_extra={
        "example": {
            "phone_number": "+886912345678"
        }
    })


class AuthStartResponse(BaseModel):
    """Response after starting auth."""
    message: str
    expires_in_seconds: int
    # In development, OTP is returned for testing
    otp_code: Optional[str] = None


class AuthVerifyRequest(BaseModel):
    """Verify OTP and get tokens."""
    phone_number: Optional[str] = None
    email: Optional[str] = None
    otp_code: str = Field(..., min_length=4, max_length=10)


class TokenPair(BaseModel):
    """Access and refresh token pair."""
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int  # seconds


class AuthVerifyResponse(BaseModel):
    """Response after successful verification."""
    user: dict
    tokens: TokenPair


class TokenRefreshRequest(BaseModel):
    """Refresh access token."""
    refresh_token: str


class LogoutRequest(BaseModel):
    """Logout request."""
    refresh_token: Optional[str] = None


# ============================================
# User Schemas
# ============================================

class UserProfile(BaseModel):
    """User profile response."""
    model_config = ConfigDict(from_attributes=True)
    
    id: UUID
    phone_number: Optional[str] = None
    email: Optional[str] = None
    full_name: Optional[str] = None
    preferred_language: str = "zh-TW"
    enable_biometric_lock: bool = False
    enable_push_notifications: bool = True
    created_at: datetime
    last_login_at: Optional[datetime] = None


class UserProfileUpdate(BaseModel):
    """Update user profile."""
    full_name: Optional[str] = Field(None, max_length=255)
    preferred_language: Optional[str] = Field(None, pattern=r'^[a-z]{2}-[A-Z]{2}$')
    enable_biometric_lock: Optional[bool] = None
    enable_push_notifications: Optional[bool] = None


# ============================================
# Card Schemas
# ============================================

class SupportedBank(str):
    """Supported bank issuers."""
    CTBC = "CTBC"
    CATHAY_UNITED = "Cathay United Bank"
    TAISHIN = "Taishin Bank"


class CardCreate(BaseModel):
    """Create a new credit card."""
    issuer_bank: str = Field(..., max_length=100)
    last_four: str = Field(..., pattern=r'^[0-9]{4}$')
    nickname: Optional[str] = Field(None, max_length=100)
    card_color: Optional[str] = Field(None, pattern=r'^#[0-9A-Fa-f]{6}$')


class CardUpdate(BaseModel):
    """Update credit card."""
    nickname: Optional[str] = Field(None, max_length=100)
    card_color: Optional[str] = Field(None, pattern=r'^#[0-9A-Fa-f]{6}$')
    is_active: Optional[bool] = None


class CardResponse(BaseModel):
    """Card response."""
    model_config = ConfigDict(from_attributes=True)
    
    id: UUID
    issuer_bank: str
    last_four: str
    nickname: Optional[str] = None
    card_color: Optional[str] = None
    is_active: bool
    created_at: datetime
    
    @property
    def display_name(self) -> str:
        if self.nickname:
            return f"{self.nickname} ({self.issuer_bank} ****{self.last_four})"
        return f"{self.issuer_bank} ****{self.last_four}"


class CardListResponse(BaseModel):
    """List of cards response."""
    cards: List[CardResponse]


# ============================================
# Bill Schemas
# ============================================

class BillStatus(str):
    """Bill status enum."""
    PENDING_REVIEW = "pending_review"
    UNPAID = "unpaid"
    PAID_CONFIRMED = "paid_confirmed"


class BillCreateFromUpload(BaseModel):
    """Create bill from uploaded statement."""
    card_id: UUID


class BillUpdate(BaseModel):
    """Update extracted bill data (for review)."""
    total_amount_due: Optional[Decimal] = None
    minimum_due: Optional[Decimal] = None
    due_date: Optional[date] = None
    statement_date: Optional[date] = None
    review_notes: Optional[str] = None


class BillConfirmPaid(BaseModel):
    """Confirm bill as paid."""
    confirmed: bool = True


class BillResponse(BaseModel):
    """Bill response."""
    model_config = ConfigDict(from_attributes=True)
    
    id: UUID
    card_id: UUID
    card: CardResponse
    
    statement_date: date
    statement_month: str
    due_date: date
    
    total_amount_due: Decimal
    minimum_due: Optional[Decimal] = None
    currency: str
    
    extraction_confidence: Decimal
    requires_review: bool
    reviewed_by_user: bool
    review_notes: Optional[str] = None
    
    status: str
    paid_confirmed_at: Optional[datetime] = None
    
    is_overdue: bool = False
    days_until_due: int
    
    created_at: datetime
    updated_at: Optional[datetime] = None


class BillListResponse(BaseModel):
    """List of bills response."""
    bills: List[BillResponse]
    upcoming_total: Decimal
    overdue_count: int


class BillDashboardResponse(BaseModel):
    """Dashboard data response."""
    next_due_bill: Optional[BillResponse] = None
    upcoming_bills: List[BillResponse]
    total_upcoming_amount: Decimal
    bills_by_status: dict


# ============================================
# Upload Schemas
# ============================================

class UploadResponse(BaseModel):
    """Upload response."""
    artifact_id: UUID
    filename: str
    status: str
    message: str
    estimated_processing_time_seconds: int = 30


class ProcessingStatusResponse(BaseModel):
    """Processing status response."""
    artifact_id: UUID
    status: str  # pending, processing, completed, failed
    progress_percent: Optional[int] = None
    bill_id: Optional[UUID] = None
    error: Optional[str] = None
    created_at: datetime
    updated_at: Optional[datetime] = None


# ============================================
# Email Webhook Schemas
# ============================================

class EmailWebhookPayload(BaseModel):
    """Email webhook payload."""
    to: str
    from_email: str
    subject: str
    body_text: Optional[str] = None
    body_html: Optional[str] = None
    attachments: List[dict] = []
    received_at: datetime


class EmailWebhookResponse(BaseModel):
    """Email webhook response."""
    accepted: bool
    message: str
    artifact_ids: List[UUID] = []


# ============================================
# Reminder Schemas
# ============================================

class ReminderResponse(BaseModel):
    """Reminder response."""
    model_config = ConfigDict(from_attributes=True)
    
    id: UUID
    bill_id: UUID
    scheduled_at: datetime
    notification_type: str
    send_status: str
    sent_at: Optional[datetime] = None


class ReminderListResponse(BaseModel):
    """List of reminders response."""
    reminders: List[ReminderResponse]
