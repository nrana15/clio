"""
Rate limiting middleware for CLIO API.
Implements token bucket algorithm with Redis backend.
"""
import time
from typing import Optional, Dict
from dataclasses import dataclass
from enum import Enum

from fastapi import Request, Response
from fastapi.responses import JSONResponse
from starlette.middleware.base import BaseHTTPMiddleware
import redis.asyncio as redis

from app.core.config import get_settings

settings = get_settings()


class RateLimitTier(str, Enum):
    """Rate limiting tiers."""
    ANONYMOUS = "anonymous"
    AUTHENTICATED = "authenticated"
    PREMIUM = "premium"


@dataclass
class RateLimitConfig:
    """Rate limit configuration."""
    requests: int
    window: int  # seconds
    burst: int   # allowed burst


# Rate limit configurations per tier
RATE_LIMITS: Dict[RateLimitTier, RateLimitConfig] = {
    RateLimitTier.ANONYMOUS: RateLimitConfig(
        requests=20,
        window=60,
        burst=5
    ),
    RateLimitTier.AUTHENTICATED: RateLimitConfig(
        requests=100,
        window=60,
        burst=10
    ),
    RateLimitTier.PREMIUM: RateLimitConfig(
        requests=1000,
        window=60,
        burst=50
    ),
}


class RateLimitExceeded(Exception):
    """Raised when rate limit is exceeded."""
    def __init__(self, retry_after: int):
        self.retry_after = retry_after
        super().__init__(f"Rate limit exceeded. Retry after {retry_after} seconds")


class RateLimiter:
    """
    Token bucket rate limiter using Redis.
    
    Each client is identified by their IP address + user ID (if authenticated).
    """
    
    def __init__(self, redis_client: Optional[redis.Redis] = None):
        self.redis = redis_client
        self._local_cache: Dict[str, Dict] = {}
    
    def _get_key(self, identifier: str, tier: RateLimitTier) -> str:
        """Generate Redis key for rate limit."""
        return f"ratelimit:{tier.value}:{identifier}"
    
    async def is_allowed(
        self,
        identifier: str,
        tier: RateLimitTier = RateLimitTier.ANONYMOUS
    ) -> tuple[bool, Dict]:
        """
        Check if request is allowed under rate limit.
        
        Args:
            identifier: Client identifier (IP + user ID)
            tier: Rate limit tier
            
        Returns:
            Tuple of (allowed, rate_limit_info)
        """
        config = RATE_LIMITS[tier]
        key = self._get_key(identifier, tier)
        now = time.time()
        
        # Use Redis if available, otherwise use local cache (for testing)
        if self.redis:
            return await self._check_redis(key, config, now)
        else:
            return self._check_local(identifier, config, now)
    
    async def _check_redis(
        self,
        key: str,
        config: RateLimitConfig,
        now: float
    ) -> tuple[bool, Dict]:
        """Check rate limit using Redis."""
        pipe = self.redis.pipeline()
        
        # Get current bucket state
        pipe.hmget(key, "tokens", "last_update")
        result = await pipe.execute()
        
        tokens_str, last_update_str = result[0]
        
        if tokens_str is None:
            # New bucket
            tokens = config.requests
            last_update = now
        else:
            tokens = float(tokens_str)
            last_update = float(last_update_str)
        
        # Calculate token replenishment
        time_passed = now - last_update
        tokens_to_add = time_passed * (config.requests / config.window)
        tokens = min(config.requests, tokens + tokens_to_add)
        
        # Check if request can be processed
        allowed = tokens >= 1
        
        if allowed:
            tokens -= 1
        
        # Update bucket
        await self.redis.hmset(key, {
            "tokens": tokens,
            "last_update": now
        })
        await self.redis.expire(key, config.window)
        
        # Calculate retry after if not allowed
        retry_after = 0
        if not allowed:
            retry_after = int((1 - tokens) * (config.window / config.requests))
        
        rate_limit_info = {
            "limit": config.requests,
            "remaining": int(tokens),
            "reset": int(now + config.window),
            "retry_after": retry_after if not allowed else 0
        }
        
        return allowed, rate_limit_info
    
    def _check_local(
        self,
        identifier: str,
        config: RateLimitConfig,
        now: float
    ) -> tuple[bool, Dict]:
        """Check rate limit using local cache (fallback for testing)."""
        key = identifier
        
        if key not in self._local_cache:
            self._local_cache[key] = {
                "tokens": config.requests,
                "last_update": now
            }
        
        bucket = self._local_cache[key]
        
        # Calculate token replenishment
        time_passed = now - bucket["last_update"]
        tokens_to_add = time_passed * (config.requests / config.window)
        bucket["tokens"] = min(config.requests, bucket["tokens"] + tokens_to_add)
        bucket["last_update"] = now
        
        # Check if request can be processed
        allowed = bucket["tokens"] >= 1
        
        if allowed:
            bucket["tokens"] -= 1
        
        # Calculate retry after if not allowed
        retry_after = 0
        if not allowed:
            retry_after = int((1 - bucket["tokens"]) * (config.window / config.requests))
        
        # Cleanup old entries
        self._cleanup_local_cache(now)
        
        rate_limit_info = {
            "limit": config.requests,
            "remaining": int(bucket["tokens"]),
            "reset": int(now + config.window),
            "retry_after": retry_after if not allowed else 0
        }
        
        return allowed, rate_limit_info
    
    def _cleanup_local_cache(self, now: float):
        """Remove expired entries from local cache."""
        # Simple cleanup: remove entries older than window * 2
        expired = []
        for key, bucket in self._local_cache.items():
            if now - bucket["last_update"] > 120:  # 2 minutes
                expired.append(key)
        
        for key in expired:
            del self._local_cache[key]


class RateLimitMiddleware(BaseHTTPMiddleware):
    """
    Middleware to enforce rate limiting on all requests.
    
    Adds rate limit headers to responses:
    - X-RateLimit-Limit: Maximum requests allowed
    - X-RateLimit-Remaining: Remaining requests in window
    - X-RateLimit-Reset: Unix timestamp when limit resets
    - Retry-After: Seconds to wait (only when limited)
    """
    
    def __init__(self, app, redis_client: Optional[redis.Redis] = None):
        super().__init__(app)
        self.limiter = RateLimiter(redis_client)
    
    async def dispatch(self, request: Request, call_next) -> Response:
        """Process request with rate limiting."""
        # Skip rate limiting for health checks
        if request.url.path in ["/healthz", "/readyz", "/"]:
            return await call_next(request)
        
        # Determine client identifier
        client_ip = self._get_client_ip(request)
        user_id = getattr(request.state, "user_id", None)
        identifier = f"{client_ip}:{user_id}" if user_id else client_ip
        
        # Determine tier
        tier = RateLimitTier.AUTHENTICATED if user_id else RateLimitTier.ANONYMOUS
        
        # Check rate limit
        allowed, rate_limit_info = await self.limiter.is_allowed(identifier, tier)
        
        if not allowed:
            return JSONResponse(
                status_code=429,
                content={
                    "success": False,
                    "error": "Rate Limit Exceeded",
                    "message": "Too many requests. Please try again later.",
                    "request_id": getattr(request.state, "request_id", "unknown")
                },
                headers={
                    "Retry-After": str(rate_limit_info["retry_after"]),
                    "X-RateLimit-Limit": str(rate_limit_info["limit"]),
                    "X-RateLimit-Remaining": "0",
                    "X-RateLimit-Reset": str(rate_limit_info["reset"])
                }
            )
        
        # Process request
        response = await call_next(request)
        
        # Add rate limit headers
        response.headers["X-RateLimit-Limit"] = str(rate_limit_info["limit"])
        response.headers["X-RateLimit-Remaining"] = str(rate_limit_info["remaining"])
        response.headers["X-RateLimit-Reset"] = str(rate_limit_info["reset"])
        
        return response
    
    def _get_client_ip(self, request: Request) -> str:
        """Extract client IP from request."""
        # Check for forwarded headers (behind proxy)
        forwarded_for = request.headers.get("X-Forwarded-For")
        if forwarded_for:
            return forwarded_for.split(",")[0].strip()
        
        real_ip = request.headers.get("X-Real-IP")
        if real_ip:
            return real_ip
        
        # Fall back to direct connection
        if request.client:
            return request.client.host
        
        return "unknown"


# Global rate limiter instance
_rate_limiter: Optional[RateLimiter] = None


def get_rate_limiter() -> RateLimiter:
    """Get global rate limiter instance."""
    global _rate_limiter
    if _rate_limiter is None:
        _rate_limiter = RateLimiter()
    return _rate_limiter
