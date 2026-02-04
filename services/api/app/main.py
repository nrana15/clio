"""
CLIO FastAPI Application
"""
from contextlib import asynccontextmanager
import time
import uuid

from fastapi import FastAPI, Request, Response
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.api.v1.api import api_router
from app.core.config import get_settings

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
    description="Credit Card Bill Aggregator API",
    version="1.0.0",
    docs_url="/docs" if settings.environment != "production" else None,
    redoc_url="/redoc" if settings.environment != "production" else None,
    openapi_url="/openapi.json" if settings.environment != "production" else None,
    lifespan=lifespan,
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000", "http://localhost:8080"] if settings.environment == "development" else [],
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allow_headers=["*"],
    max_age=600,
)


@app.middleware("http")
async def request_middleware(request: Request, call_next):
    """Request middleware for logging and request ID."""
    # Generate request ID
    request_id = str(uuid.uuid4())
    request.state.request_id = request_id
    
    # Start timer
    start_time = time.time()
    
    # Process request
    try:
        response = await call_next(request)
    except Exception as exc:
        response = JSONResponse(
            status_code=500,
            content={
                "success": False,
                "error": "Internal Server Error",
                "message": str(exc) if settings.debug else "An unexpected error occurred",
                "request_id": request_id
            }
        )
    
    # Add headers
    response.headers["X-Request-ID"] = request_id
    response.headers["X-Response-Time"] = str(round((time.time() - start_time) * 1000, 2))
    
    return response


# Health check endpoints
@app.get("/healthz", tags=["Health"])
async def health_check():
    """Liveness probe."""
    return {"status": "healthy"}


@app.get("/readyz", tags=["Health"])
async def readiness_check():
    """Readiness probe."""
    # TODO: Check database connectivity
    return {"status": "ready"}


# API routes
app.include_router(api_router, prefix="/api/v1")


@app.get("/", tags=["Root"])
async def root():
    """API root."""
    return {
        "name": "CLIO API",
        "version": "1.0.0",
        "description": "Credit Card Bill Aggregator",
        "docs": "/docs"
    }
