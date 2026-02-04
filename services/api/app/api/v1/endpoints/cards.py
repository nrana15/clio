"""
Card management endpoints
"""
from typing import List
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_

from app.db.session import get_db
from app.models.models import User, Card
from app.schemas.schemas import CardCreate, CardUpdate, CardResponse, CardListResponse

router = APIRouter()


async def get_current_user(db: AsyncSession = Depends(get_db)) -> User:
    """Get current authenticated user (placeholder for JWT auth)."""
    # TODO: Implement JWT verification
    # For now, return first user for testing
    result = await db.execute(select(User).limit(1))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Not authenticated"
        )
    return user


@router.post("", response_model=CardResponse, status_code=status.HTTP_201_CREATED)
async def create_card(
    card_data: CardCreate,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Add a new credit card."""
    # Validate issuer bank
    supported_banks = ["CTBC", "Cathay United Bank", "Taishin Bank"]
    if card_data.issuer_bank not in supported_banks:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Unsupported bank. Supported: {', '.join(supported_banks)}"
        )
    
    # Check for duplicate (same user, bank, last4)
    existing_query = select(Card).where(
        and_(
            Card.user_id == user.id,
            Card.issuer_bank == card_data.issuer_bank,
            Card.last_four == card_data.last_four
        )
    )
    result = await db.execute(existing_query)
    if result.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Card already exists"
        )
    
    # Create card
    card = Card(
        user_id=user.id,
        issuer_bank=card_data.issuer_bank,
        last_four=card_data.last_four,
        nickname=card_data.nickname,
        card_color=card_data.card_color
    )
    
    db.add(card)
    await db.commit()
    await db.refresh(card)
    
    return card


@router.get("", response_model=CardListResponse)
async def list_cards(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """List all user's credit cards."""
    query = select(Card).where(
        Card.user_id == user.id
    ).order_by(Card.created_at.desc())
    
    result = await db.execute(query)
    cards = result.scalars().all()
    
    return CardListResponse(cards=list(cards))


@router.get("/{card_id}", response_model=CardResponse)
async def get_card(
    card_id: UUID,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Get a specific card."""
    query = select(Card).where(
        and_(Card.id == card_id, Card.user_id == user.id)
    )
    result = await db.execute(query)
    card = result.scalar_one_or_none()
    
    if not card:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Card not found"
        )
    
    return card


@router.patch("/{card_id}", response_model=CardResponse)
async def update_card(
    card_id: UUID,
    card_data: CardUpdate,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Update a credit card."""
    query = select(Card).where(
        and_(Card.id == card_id, Card.user_id == user.id)
    )
    result = await db.execute(query)
    card = result.scalar_one_or_none()
    
    if not card:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Card not found"
        )
    
    # Update fields
    update_data = card_data.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(card, field, value)
    
    await db.commit()
    await db.refresh(card)
    
    return card


@router.delete("/{card_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_card(
    card_id: UUID,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Delete a credit card."""
    query = select(Card).where(
        and_(Card.id == card_id, Card.user_id == user.id)
    )
    result = await db.execute(query)
    card = result.scalar_one_or_none()
    
    if not card:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Card not found"
        )
    
    # Soft delete
    card.is_active = False
    await db.commit()
    
    return None
