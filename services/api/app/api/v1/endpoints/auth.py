"""
Authentication endpoints
"""
from datetime import datetime, timedelta
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, status, Request
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.db.session import get_db
from app.models.models import User, OTPAttempt
from app.schemas.schemas import (
    AuthStartRequest, AuthStartResponse, AuthVerifyRequest,
    AuthVerifyResponse, TokenRefreshRequest, TokenPair, LogoutRequest
)
from app.services.auth_service import AuthService
from app.core.config import get_settings

router = APIRouter()
settings = get_settings()


@router.post("/start", response_model=AuthStartResponse)
async def auth_start(
    request: Request,
    auth_request: AuthStartRequest,
    db: AsyncSession = Depends(get_db)
):
    """
    Start authentication by sending OTP to phone or email.
    """
    if not auth_request.phone_number and not auth_request.email:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Either phone_number or email is required"
        )
    
    # Generate OTP
    otp_code = AuthService.generate_otp(settings.otp_length)
    expires_at = datetime.utcnow() + timedelta(minutes=settings.otp_expire_minutes)
    
    # Create OTP attempt record
    otp_attempt = OTPAttempt(
        phone_number=auth_request.phone_number,
        email=auth_request.email,
        otp_code=AuthService.hash_otp(otp_code),  # Store hashed
        expires_at=expires_at,
        ip_address=request.client.host if request.client else None
    )
    
    db.add(otp_attempt)
    await db.commit()
    
    # TODO: Send OTP via SMS/Email in production
    # For development, return OTP in response
    response_data = {
        "message": "OTP sent successfully",
        "expires_in_seconds": settings.otp_expire_minutes * 60
    }
    
    if settings.environment == "development":
        response_data["otp_code"] = otp_code
        print(f"🔐 DEV OTP for {auth_request.phone_number or auth_request.email}: {otp_code}")
    
    return AuthStartResponse(**response_data)


@router.post("/verify", response_model=AuthVerifyResponse)
async def auth_verify(
    request: Request,
    verify_request: AuthVerifyRequest,
    db: AsyncSession = Depends(get_db)
):
    """
    Verify OTP and return access/refresh tokens.
    """
    # Find valid OTP attempt
    query = select(OTPAttempt).where(
        OTPAttempt.phone_number == verify_request.phone_number if verify_request.phone_number else OTPAttempt.email == verify_request.email,
        OTPAttempt.verified == False,
        OTPAttempt.expires_at > datetime.utcnow()
    ).order_by(OTPAttempt.created_at.desc())
    
    result = await db.execute(query)
    otp_attempt = result.scalar_one_or_none()
    
    if not otp_attempt:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or expired OTP"
        )
    
    # Verify OTP
    if not AuthService.verify_otp(verify_request.otp_code, otp_attempt.otp_code):
        otp_attempt.attempts_count += 1
        await db.commit()
        
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid OTP"
        )
    
    # Mark OTP as verified
    otp_attempt.verified = True
    otp_attempt.verified_at = datetime.utcnow()
    
    # Get or create user
    user_query = select(User).where(
        User.phone_number == verify_request.phone_number if verify_request.phone_number else User.email == verify_request.email
    )
    result = await db.execute(user_query)
    user = result.scalar_one_or_none()
    
    if not user:
        # Create new user
        user = User(
            phone_number=verify_request.phone_number,
            email=verify_request.email,
            is_verified=True
        )
        db.add(user)
    else:
        user.is_verified = True
        user.last_login_at = datetime.utcnow()
    
    await db.commit()
    await db.refresh(user)
    
    # Generate tokens
    tokens = AuthService.create_token_pair(str(user.id))
    
    return AuthVerifyResponse(
        user={
            "id": str(user.id),
            "phone_number": user.phone_number,
            "email": user.email,
            "full_name": user.full_name,
            "is_verified": user.is_verified
        },
        tokens=tokens
    )


@router.post("/refresh", response_model=TokenPair)
async def auth_refresh(refresh_request: TokenRefreshRequest):
    """
    Refresh access token using refresh token.
    """
    tokens = AuthService.refresh_access_token(refresh_request.refresh_token)
    
    if not tokens:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired refresh token"
        )
    
    return tokens


@router.post("/logout")
async def auth_logout(
    logout_request: LogoutRequest,
    db: AsyncSession = Depends(get_db)
):
    """
    Logout user and revoke refresh token.
    """
    # TODO: Add refresh token to revocation list in Redis
    return {"message": "Logged out successfully"}
