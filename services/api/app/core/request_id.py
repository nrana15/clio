"""
Request ID middleware for request tracing.
"""
import uuid
from typing import Optional

from fastapi import Request
from starlette.middleware.base import BaseHTTPMiddleware


class RequestIDMiddleware(BaseHTTPMiddleware):
    """
    Middleware to generate and propagate request IDs.
    
    Request IDs enable:
    - Request tracing across services
    - Debugging and log correlation
    - API support (users can reference specific requests)
    
    The middleware:
    1. Checks for X-Request-ID header from client
    2. Generates new UUID if not provided
    3. Attaches request ID to request state
    4. Adds X-Request-ID header to response
    """
    
    def __init__(
        self,
        app,
        header_name: str = "X-Request-ID",
        generator = None
    ):
        super().__init__(app)
        self.header_name = header_name
        self.generator = generator or (lambda: str(uuid.uuid4()))
    
    async def dispatch(self, request: Request, call_next):
        """Add request ID to request and response."""
        # Check for existing request ID from client or upstream
        request_id = request.headers.get(self.header_name)
        
        # Generate new ID if not provided
        if not request_id:
            request_id = self.generator()
        
        # Attach to request state for access in endpoints
        request.state.request_id = request_id
        
        # Process request
        response = await call_next(request)
        
        # Add request ID to response headers
        response.headers[self.header_name] = request_id
        
        return response


def get_request_id(request: Request) -> str:
    """Get request ID from request state."""
    return getattr(request.state, "request_id", "unknown")
