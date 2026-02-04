"""
Authentication service with OTP and JWT
"""
from datetime import datetime, timedelta
from typing import Optional, Tuple
import secrets
import hashlib

from jose import JWTError, jwt
from passlib.context import CryptContext

from app.core.config import get_settings
from app.schemas.schemas import TokenPair

settings = get_settings()
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


class AuthService:
    """Authentication service with OTP and JWT."""
    
    @staticmethod
    def generate_otp(length: int = 6) -> str:
        """Generate a secure OTP code."""
        # Generate cryptographically secure OTP
        min_val = 10 ** (length - 1)
        max_val = (10 ** length) - 1
        otp = secrets.randbelow(max_val - min_val + 1) + min_val
        return str(otp)
    
    @staticmethod
    def hash_otp(otp: str) -> str:
        """Hash OTP for secure storage."""
        return hashlib.sha256(otp.encode()).hexdigest()
    
    @staticmethod
    def verify_otp(plain_otp: str, hashed_otp: str) -> bool:
        """Verify OTP against hash."""
        return AuthService.hash_otp(plain_otp) == hashed_otp
    
    @staticmethod
    def create_access_token(user_id: str, expires_delta: Optional[timedelta] = None) -> str:
        """Create JWT access token."""
        if expires_delta is None:
            expires_delta = timedelta(minutes=settings.access_token_expire_minutes)
        
        expire = datetime.utcnow() + expires_delta
        
        to_encode = {
            "sub": user_id,
            "exp": expire,
            "type": "access",
            "iat": datetime.utcnow(),
        }
        
        encoded_jwt = jwt.encode(
            to_encode, 
            settings.jwt_secret, 
            algorithm=settings.jwt_algorithm
        )
        return encoded_jwt
    
    @staticmethod
    def create_refresh_token(user_id: str) -> Tuple[str, datetime]:
        """Create JWT refresh token with expiration."""
        expires_delta = timedelta(days=settings.refresh_token_expire_days)
        expire = datetime.utcnow() + expires_delta
        
        to_encode = {
            "sub": user_id,
            "exp": expire,
            "type": "refresh",
            "iat": datetime.utcnow(),
            "jti": secrets.token_urlsafe(32),  # Unique token ID for revocation
        }
        
        encoded_jwt = jwt.encode(
            to_encode,
            settings.jwt_secret,
            algorithm=settings.jwt_algorithm
        )
        return encoded_jwt, expire
    
    @staticmethod
    def decode_token(token: str) -> Optional[dict]:
        """Decode and validate JWT token."""
        try:
            payload = jwt.decode(
                token,
                settings.jwt_secret,
                algorithms=[settings.jwt_algorithm]
            )
            return payload
        except JWTError:
            return None
    
    @staticmethod
    def get_token_expiry(token: str) -> Optional[datetime]:
        """Get token expiration time."""
        payload = AuthService.decode_token(token)
        if payload and "exp" in payload:
            return datetime.utcfromtimestamp(payload["exp"])
        return None
    
    @staticmethod
    def create_token_pair(user_id: str) -> TokenPair:
        """Create both access and refresh tokens."""
        access_token = AuthService.create_access_token(user_id)
        refresh_token, _ = AuthService.create_refresh_token(user_id)
        
        return TokenPair(
            access_token=access_token,
            refresh_token=refresh_token,
            token_type="bearer",
            expires_in=settings.access_token_expire_minutes * 60
        )
    
    @staticmethod
    def refresh_access_token(refresh_token: str) -> Optional[TokenPair]:
        """Create new token pair from valid refresh token."""
        payload = AuthService.decode_token(refresh_token)
        
        if not payload:
            return None
        
        # Verify it's a refresh token
        if payload.get("type") != "refresh":
            return None
        
        user_id = payload.get("sub")
        if not user_id:
            return None
        
        # TODO: Check if refresh token is revoked in Redis
        
        return AuthService.create_token_pair(user_id)
