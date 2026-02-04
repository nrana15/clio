"""
File upload endpoints
"""
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File, Form
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.schemas.schemas import UploadResponse, ProcessingStatusResponse
from app.api.v1.endpoints.cards import get_current_user

router = APIRouter()


@router.post("/statement", response_model=UploadResponse)
async def upload_statement(
    card_id: UUID = Form(...),
    file: UploadFile = File(...),
    user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Upload a credit card statement (PDF or image)."""
    # Validate file type
    allowed_types = ["application/pdf", "image/jpeg", "image/png", "image/heic"]
    if file.content_type not in allowed_types:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid file type. Allowed: {', '.join(allowed_types)}"
        )
    
    # TODO: Implement actual upload to MinIO
    # TODO: Create SourceArtifact record
    # TODO: Enqueue parsing job
    
    return UploadResponse(
        artifact_id=UUID("00000000-0000-0000-0000-000000000000"),
        filename=file.filename,
        status="pending",
        message="Upload received, processing started",
        estimated_processing_time_seconds=30
    )


@router.get("/status/{artifact_id}", response_model=ProcessingStatusResponse)
async def get_upload_status(
    artifact_id: UUID,
    user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Get processing status of an uploaded statement."""
    # TODO: Implement status check
    return ProcessingStatusResponse(
        artifact_id=artifact_id,
        status="pending",
        progress_percent=0,
        created_at=None,
        updated_at=None
    )
