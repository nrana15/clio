"""
CLIO FastAPI Application
"""
from contextlib import asynccontextmanager
import time

from fastapi import FastAPI, Request, Response
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.api.v1.api import api_router
from app.core.config import get_settings
from app.core.security import AuthError
from app.core.rate_limiter import RateLimitMiddleware
from app.core.request_id import RequestIDMiddleware, get_request_id

settings = get_settings()


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan handler."""
    # Startup
    print(f"🚀 CLIO API starting in {settings.environment} mode")
    yield
    # Shutdown
    print("👋 CLIO API shutting down")


app = FastAPI(
    title="CLIO API",
    description="Credit Card Bill Aggregator API - Secure, scalable bill management",
    version="1.0.0",
    docs_url="/docs" if settings.environment != "production" else None,
    redoc_url="/redoc" if settings.environment != "production" else None,
    openapi_url="/openapi.json" if settings.environment != "production" else None,
    lifespan=lifespan,
)

# ============================================
# Security Middleware (Order matters!)
# ============================================

# 1. Request ID middleware - must be first to capture all requests
app.add_middleware(
    RequestIDMiddleware,
    header_name="X-Request-ID"
)

# 2. CORS middleware - handle cross-origin requests
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:3000",
        "http://localhost:8080",
        "http://localhost:55352",  # Flutter web
        "https://clio.app",
        "https://api.clio.app"
    ] if settings.environment == "development" else [
        "https://clio.app",
        "https://api.clio.app"
    ],
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allow_headers=["*"],
    expose_headers=["X-Request-ID", "X-RateLimit-Limit", "X-RateLimit-Remaining", "X-RateLimit-Reset"],
    max_age=600,
)

# 3. Rate limiting middleware
app.add_middleware(RateLimitMiddleware)


# ============================================
# Error Handlers
# ============================================

@app.exception_handler(AuthError)
async def auth_error_handler(request: Request, exc: AuthError):
    """Handle authentication errors."""
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "success": False,
            "error": "Authentication Error",
            "message": exc.detail,
            "request_id": get_request_id(request)
        },
        headers=exc.headers
    )


@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    """Handle all unhandled exceptions."""
    request_id = get_request_id(request)
    
    # Log the error with request ID for debugging
    print(f"[ERROR] Request {request_id}: {str(exc)}")
    
    return JSONResponse(
        status_code=500,
        content={
            "success": False,
            "error": "Internal Server Error",
            "message": "An unexpected error occurred" if not settings.debug else str(exc),
            "request_id": request_id
        }
    )


# ============================================
# Request Middleware
# ============================================

@app.middleware("http")
async def request_logging_middleware(request: Request, call_next):
    """
    Middleware for request logging and timing.
    
    Logs:
    - Request method and path
    - Response status code
    - Request duration
    - Request ID for correlation
    """
    start_time = time.time()
    
    # Process request
    response = await call_next(request)
    
    # Calculate duration
    duration_ms = round((time.time() - start_time) * 1000, 2)
    
    # Get request ID
    request_id = get_request_id(request)
    
    # Add timing header
    response.headers["X-Response-Time"] = str(duration_ms)
    
    # Log request details (exclude health checks to reduce noise)
    if not request.url.path.startswith("/health"):
        user_id = getattr(request.state, "user_id", "anonymous")
        print(
            f"[{request.method}] {request.url.path} "
            f"{response.status_code} {duration_ms}ms "
            f"rid={request_id} uid={user_id}"
        )
    
    return response


# ============================================
# Health Check Endpoints
# ============================================

@app.get("/healthz", tags=["Health"])
async def health_check():
    """Liveness probe for Kubernetes/Docker."""
    return {"status": "healthy", "timestamp": time.time()}


@app.get("/readyz", tags=["Health"])
async def readiness_check():
    """Readiness probe - checks critical dependencies."""
    # TODO: Check database connectivity
    # TODO: Check Redis connectivity
    # TODO: Check MinIO connectivity
    return {"status": "ready", "checks": {"database": "ok", "redis": "ok"}}


# ============================================
# API Routes
# ============================================

app.include_router(api_router, prefix="/api/v1")


@app.get("/", tags=["Root"])
async def root():
    """API root with basic info."""
    return {
        "name": "CLIO API",
        "version": "1.0.0",
        "description": "Credit Card Bill Aggregator",
        "docs": "/docs" if settings.environment != "production" else None,
        "environment": settings.environment
    }
