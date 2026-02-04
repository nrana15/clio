"""
Bill management endpoints
"""
from datetime import date
from typing import Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_, func
from sqlalchemy.orm import selectinload

from app.db.session import get_db
from app.models.models import User, Bill, Card, BillStatus
from app.schemas.schemas import (
    BillCreateFromUpload, BillUpdate, BillResponse, BillListResponse,
    BillDashboardResponse, BillConfirmPaid
)
from app.api.v1.endpoints.cards import get_current_user

router = APIRouter()


@router.get("/dashboard", response_model=BillDashboardResponse)
async def get_dashboard(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Get dashboard data with next due bill and upcoming bills."""
    today = date.today()
    
    # Get next due bill (closest upcoming)
    next_due_query = select(Bill).where(
        and_(
            Bill.user_id == user.id,
            Bill.status.in_([BillStatus.PENDING_REVIEW, BillStatus.UNPAID]),
            Bill.due_date >= today
        )
    ).order_by(Bill.due_date.asc()).options(
        selectinload(Bill.card)
    ).limit(1)
    
    result = await db.execute(next_due_query)
    next_due_bill = result.scalar_one_or_none()
    
    # Get upcoming bills (next 30 days, excluding next due)
    upcoming_query = select(Bill).where(
        and_(
            Bill.user_id == user.id,
            Bill.status.in_([BillStatus.PENDING_REVIEW, BillStatus.UNPAID]),
            Bill.due_date >= today
        )
    ).order_by(Bill.due_date.asc()).options(
        selectinload(Bill.card)
    )
    
    result = await db.execute(upcoming_query)
    all_upcoming = result.scalars().all()
    
    # Separate next due from upcoming list
    upcoming_bills = []
    if len(all_upcoming) > 1:
        upcoming_bills = list(all_upcoming[1:6])  # Next 5 after the hero
    
    # Calculate totals
    total_upcoming = sum(bill.total_amount_due for bill in all_upcoming)
    
    # Status counts
    status_counts = {}
    for status in BillStatus:
        count_query = select(func.count(Bill.id)).where(
            and_(Bill.user_id == user.id, Bill.status == status)
        )
        result = await db.execute(count_query)
        status_counts[status.value] = result.scalar()
    
    return BillDashboardResponse(
        next_due_bill=next_due_bill,
        upcoming_bills=upcoming_bills,
        total_upcoming_amount=total_upcoming,
        bills_by_status=status_counts
    )


@router.get("", response_model=BillListResponse)
async def list_bills(
    status: Optional[str] = Query(None, description="Filter by status"),
    card_id: Optional[UUID] = Query(None, description="Filter by card"),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """List all user's bills with optional filters."""
    query = select(Bill).where(Bill.user_id == user.id).options(
        selectinload(Bill.card)
    )
    
    if status:
        query = query.where(Bill.status == status)
    
    if card_id:
        query = query.where(Bill.card_id == card_id)
    
    query = query.order_by(Bill.due_date.desc())
    
    result = await db.execute(query)
    bills = result.scalars().all()
    
    # Calculate totals
    upcoming_total = sum(
        bill.total_amount_due 
        for bill in bills 
        if bill.status in [BillStatus.PENDING_REVIEW, BillStatus.UNPAID]
    )
    overdue_count = sum(
        1 for bill in bills 
        if bill.status in [BillStatus.PENDING_REVIEW, BillStatus.UNPAID] and bill.due_date < date.today()
    )
    
    return BillListResponse(
        bills=list(bills),
        upcoming_total=upcoming_total,
        overdue_count=overdue_count
    )


@router.get("/{bill_id}", response_model=BillResponse)
async def get_bill(
    bill_id: UUID,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Get a specific bill."""
    query = select(Bill).where(
        and_(Bill.id == bill_id, Bill.user_id == user.id)
    ).options(selectinload(Bill.card))
    
    result = await db.execute(query)
    bill = result.scalar_one_or_none()
    
    if not bill:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Bill not found"
        )
    
    return bill


@router.patch("/{bill_id}", response_model=BillResponse)
async def update_bill(
    bill_id: UUID,
    bill_data: BillUpdate,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Update bill data (for review/correction)."""
    query = select(Bill).where(
        and_(Bill.id == bill_id, Bill.user_id == user.id)
    ).options(selectinload(Bill.card))
    
    result = await db.execute(query)
    bill = result.scalar_one_or_none()
    
    if not bill:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Bill not found"
        )
    
    # Update fields
    update_data = bill_data.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        if field == "review_notes":
            bill.review_notes = value
            bill.reviewed_by_user = True
        elif hasattr(bill, field):
            setattr(bill, field, value)
    
    # If confidence was low and user reviewed, update status
    if bill.requires_review and bill.reviewed_by_user:
        bill.requires_review = False
    
    await db.commit()
    await db.refresh(bill)
    
    return bill


@router.post("/{bill_id}/confirm-paid", response_model=BillResponse)
async def confirm_bill_paid(
    bill_id: UUID,
    confirm_data: BillConfirmPaid,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Manually mark a bill as paid."""
    if not confirm_data.confirmed:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Confirmation required"
        )
    
    query = select(Bill).where(
        and_(Bill.id == bill_id, Bill.user_id == user.id)
    ).options(selectinload(Bill.card))
    
    result = await db.execute(query)
    bill = result.scalar_one_or_none()
    
    if not bill:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Bill not found"
        )
    
    from datetime import datetime
    bill.status = BillStatus.PAID_CONFIRMED
    bill.paid_confirmed_at = datetime.utcnow()
    bill.paid_confirmed_by = "user"
    
    await db.commit()
    await db.refresh(bill)
    
    return bill
