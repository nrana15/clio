"""
CLIO FastAPI Application
"""
from contextlib import asynccontextmanager
import time
import asyncio

from fastapi import FastAPI, Request, Response
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, PlainTextResponse

from app.api.v1.api import api_router
from app.core.config import get_settings
from app.core.security import AuthError
from app.core.rate_limiter import RateLimitMiddleware
from app.core.request_id import RequestIDMiddleware, get_request_id

# Prometheus metrics
try:
    from prometheus_client import Counter, Histogram, Gauge, generate_latest, CONTENT_TYPE_LATEST
    PROMETHEUS_AVAILABLE = True
except ImportError:
    PROMETHEUS_AVAILABLE = False

settings = get_settings()

# Prometheus metrics setup
if PROMETHEUS_AVAILABLE:
    REQUEST_COUNT = Counter(
        'http_requests_total',
        'Total HTTP requests',
        ['method', 'endpoint', 'status_code']
    )
    REQUEST_LATENCY = Histogram(
        'http_request_duration_seconds',
        'HTTP request latency',
        ['method', 'endpoint']
    )
    ACTIVE_CONNECTIONS = Gauge(
        'active_connections',
        'Number of active connections'
    )


async def check_database_health() -> dict:
    """Check database connectivity."""
    try:
        from app.db.session import async_engine
        from sqlalchemy import text
        
        async with async_engine.connect() as conn:
            result = await conn.execute(text("SELECT 1"))
            await result.scalar()
        return {"status": "ok", "latency_ms": 0}
    except Exception as e:
        return {"status": "error", "message": str(e)}


async def check_redis_health() -> dict:
    """Check Redis connectivity."""
    try:
        import aioredis
        redis = aioredis.from_url(settings.redis_url)
        await redis.ping()
        await redis.close()
        return {"status": "ok", "latency_ms": 0}
    except Exception as e:
        return {"status": "error", "message": str(e)}


async def check_storage_health() -> dict:
    """Check MinIO/S3 storage connectivity."""
    try:
        from app.services.storage_service import get_storage_service
        storage = get_storage_service()
        # Try to list bucket (lightweight operation)
        async with storage._get_client() as client:
            await client.head_bucket(Bucket=settings.minio_bucket)
        return {"status": "ok", "latency_ms": 0}
    except Exception as e:
        return {"status": "error", "message": str(e)}


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan handler."""
    # Startup
    print(f"🚀 CLIO API starting in {settings.environment} mode")
    print(f"📊 Metrics enabled: {settings.enable_metrics and PROMETHEUS_AVAILABLE}")
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
    Middleware for request logging, timing, and metrics.
    """
    start_time = time.time()
    
    if PROMETHEUS_AVAILABLE:
        ACTIVE_CONNECTIONS.inc()
    
    try:
        # Process request
        response = await call_next(request)
        
        # Calculate duration
        duration_ms = round((time.time() - start_time) * 1000, 2)
        duration_s = duration_ms / 1000
        
        # Get request ID
        request_id = get_request_id(request)
        
        # Add timing header
        response.headers["X-Response-Time"] = str(duration_ms)
        
        # Update Prometheus metrics
        if PROMETHEUS_AVAILABLE:
            REQUEST_COUNT.labels(
                method=request.method,
                endpoint=request.url.path,
                status_code=response.status_code
            ).inc()
            REQUEST_LATENCY.labels(
                method=request.method,
                endpoint=request.url.path
            ).observe(duration_s)
        
        # Log request details (exclude health checks to reduce noise)
        if not request.url.path.startswith("/health") and request.url.path != "/metrics":
            user_id = getattr(request.state, "user_id", "anonymous")
            print(
                f"[{request.method}] {request.url.path} "
                f"{response.status_code} {duration_ms}ms "
                f"rid={request_id} uid={user_id}"
            )
        
        return response
    finally:
        if PROMETHEUS_AVAILABLE:
            ACTIVE_CONNECTIONS.dec()


# ============================================
# Health Check Endpoints
# ============================================

@app.get("/healthz", tags=["Health"])
async def health_check():
    """Liveness probe for Kubernetes/Docker."""
    return {
        "status": "healthy",
        "timestamp": time.time(),
        "version": "1.0.0"
    }


@app.get("/readyz", tags=["Health"])
async def readiness_check():
    """Readiness probe - checks critical dependencies."""
    # Run health checks in parallel
    db_health, redis_health, storage_health = await asyncio.gather(
        check_database_health(),
        check_redis_health(),
        check_storage_health(),
        return_exceptions=True
    )
    
    # Handle exceptions
    if isinstance(db_health, Exception):
        db_health = {"status": "error", "message": str(db_health)}
    if isinstance(redis_health, Exception):
        redis_health = {"status": "error", "message": str(redis_health)}
    if isinstance(storage_health, Exception):
        storage_health = {"status": "error", "message": str(storage_health)}
    
    all_healthy = all(
        h.get("status") == "ok" 
        for h in [db_health, redis_health, storage_health]
    )
    
    status_code = 200 if all_healthy else 503
    
    return JSONResponse(
        status_code=status_code,
        content={
            "status": "ready" if all_healthy else "not_ready",
            "checks": {
                "database": db_health,
                "redis": redis_health,
                "storage": storage_health
            },
            "timestamp": time.time()
        }
    )


# ============================================
# Metrics Endpoint
# ============================================

@app.get("/metrics", tags=["Monitoring"])
async def metrics():
    """Prometheus metrics endpoint."""
    if not PROMETHEUS_AVAILABLE or not settings.enable_metrics:
        return PlainTextResponse(
            "# Prometheus metrics not available\n",
            status_code=503
        )
    
    return PlainTextResponse(
        content=generate_latest(),
        media_type=CONTENT_TYPE_LATEST
    )


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
        "environment": settings.environment,
        "features": {
            "push_notifications": bool(settings.fcm_server_key),
            "email_webhook": bool(settings.email_webhook_secret),
            "metrics": settings.enable_metrics and PROMETHEUS_AVAILABLE
        }
    }
