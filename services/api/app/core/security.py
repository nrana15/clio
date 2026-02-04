"""
JWT Authentication middleware and dependencies for CLIO API.
"""
from typing import Optional
from uuid import UUID
from datetime import datetime

from fastapi import Depends, HTTPException, status, Request
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import JWTError, jwt
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.core.config import get_settings
from app.db.session import get_db
from app.models.models import User

settings = get_settings()
security = HTTPBearer(auto_error=False)


class AuthError(HTTPException):
    """Custom authentication error."""
    def __init__(self, detail: str = "Authentication failed"):
        super().__init__(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=detail,
            headers={"WWW-Authenticate": "Bearer"},
        )


class TokenData:
    """Data extracted from JWT token."""
    def __init__(
        self,
        user_id: str,
        token_type: str,
        exp: datetime,
        jti: Optional[str] = None
    ):
        self.user_id = user_id
        self.token_type = token_type
        self.exp = exp
        self.jti = jti


def decode_token(token: str) -> Optional[dict]:
    """
    Decode and validate JWT token.
    
    Returns:
        Decoded token payload or None if invalid
    """
    try:
        payload = jwt.decode(
            token,
            settings.jwt_secret,
            algorithms=[settings.jwt_algorithm]
        )
        return payload
    except JWTError:
        return None


def verify_token(token: str, expected_type: str = "access") -> TokenData:
    """
    Verify JWT token and extract data.
    
    Args:
        token: JWT token string
        expected_type: Expected token type (access or refresh)
        
    Returns:
        TokenData object with extracted information
        
    Raises:
        AuthError: If token is invalid or expired
    """
    payload = decode_token(token)
    
    if payload is None:
        raise AuthError("Invalid token")
    
    # Verify token type
    token_type = payload.get("type")
    if token_type != expected_type:
        raise AuthError(f"Invalid token type. Expected {expected_type}")
    
    # Extract user ID
    user_id = payload.get("sub")
    if not user_id:
        raise AuthError("Token missing user ID")
    
    # Extract expiration
    exp = payload.get("exp")
    if not exp:
        raise AuthError("Token missing expiration")
    
    exp_datetime = datetime.utcfromtimestamp(exp)
    if datetime.utcnow() >= exp_datetime:
        raise AuthError("Token has expired")
    
    return TokenData(
        user_id=user_id,
        token_type=token_type,
        exp=exp_datetime,
        jti=payload.get("jti")
    )


async def get_current_user(
    request: Request,
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security),
    db: AsyncSession = Depends(get_db)
) -> User:
    """
    Get current authenticated user from JWT token.
    
    This dependency:
    1. Extracts the Bearer token from Authorization header
    2. Verifies the token signature and expiration
    3. Checks token type is 'access'
    4. Looks up the user in the database
    5. Attaches user ID to request state for logging
    
    Args:
        request: FastAPI request object
        credentials: HTTP Authorization credentials
        db: Database session
        
    Returns:
        User model instance
        
    Raises:
        AuthError: If authentication fails
    """
    if not credentials:
        raise AuthError("Authorization header missing")
    
    if credentials.scheme.lower() != "bearer":
        raise AuthError("Invalid authentication scheme. Use Bearer")
    
    token = credentials.credentials
    
    # Verify token
    token_data = verify_token(token, expected_type="access")
    
    # Check if token is revoked (TODO: implement Redis check)
    # if await is_token_revoked(token_data.jti):
    #     raise AuthError("Token has been revoked")
    
    # Look up user
    try:
        user_uuid = UUID(token_data.user_id)
    except ValueError:
        raise AuthError("Invalid user ID in token")
    
    query = select(User).where(User.id == user_uuid)
    result = await db.execute(query)
    user = result.scalar_one_or_none()
    
    if not user:
        raise AuthError("User not found")
    
    if not user.is_active:
        raise AuthError("User account is disabled")
    
    # Attach user ID to request state for logging
    request.state.user_id = str(user.id)
    request.state.user_phone = user.phone_number
    
    return user


async def get_current_active_user(
    current_user: User = Depends(get_current_user)
) -> User:
    """
    Get current active user (extends get_current_user with verified check).
    
    Args:
        current_user: User from get_current_user dependency
        
    Returns:
        User model instance
        
    Raises:
        AuthError: If user is not verified
    """
    if not current_user.is_verified:
        raise AuthError("User account not verified")
    
    return current_user


async def optional_current_user(
    request: Request,
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security),
    db: AsyncSession = Depends(get_db)
) -> Optional[User]:
    """
    Optionally get current user. Returns None if not authenticated.
    
    Use this for endpoints that work with or without authentication.
    
    Args:
        request: FastAPI request object
        credentials: HTTP Authorization credentials
        db: Database session
        
    Returns:
        User model instance or None
    """
    try:
        return await get_current_user(request, credentials, db)
    except AuthError:
        return None


class AuthDependencies:
    """Container for authentication dependencies."""
    
    @staticmethod
    def require_auth():
        """Require authentication."""
        return Depends(get_current_user)
    
    @staticmethod
    def require_active():
        """Require active (verified) user."""
        return Depends(get_current_active_user)
    
    @staticmethod
    def optional():
        """Optional authentication."""
        return Depends(optional_current_user)
