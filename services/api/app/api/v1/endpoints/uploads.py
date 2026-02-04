"""
File upload endpoints
"""
from typing import Optional
from uuid import UUID
import hashlib

from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File, Form
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.db.session import get_db
from app.models.models import User, SourceArtifact, Card
from app.schemas.schemas import UploadResponse, ProcessingStatusResponse
from app.core.config import get_settings
from app.core.security import get_current_active_user

router = APIRouter()
settings = get_settings()


@router.post(
    "",
    response_model=UploadResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Upload statement",
    description="Upload a credit card statement (PDF or image)."
)
async def upload_statement(
    card_id: UUID = Form(..., description="ID of the card this statement belongs to"),
    file: UploadFile = File(..., description="PDF or image file of the statement"),
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Upload a credit card statement for processing.
    
    Supported formats:
    - PDF (.pdf)
    - JPEG (.jpg, .jpeg)
    - PNG (.png)
    - HEIC (.heic)
    
    Max file size: 10MB
    """
    # Validate card belongs to user
    card_query = select(Card).where(
        Card.id == card_id,
        Card.user_id == user.id
    )
    result = await db.execute(card_query)
    card = result.scalar_one_or_none()
    
    if not card:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Card not found"
        )
    
    # Validate file type
    content_type = file.content_type or ""
    if content_type not in settings.allowed_upload_mime_types:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Unsupported file type. Allowed: {', '.join(settings.allowed_upload_mime_types)}"
        )
    
    # Read file content
    content = await file.read()
    
    # Validate file size
    file_size = len(content)
    max_size = settings.max_upload_size_mb * 1024 * 1024
    if file_size > max_size:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail=f"File too large. Max size: {settings.max_upload_size_mb}MB"
        )
    
    # Calculate checksum
    checksum = hashlib.sha256(content).hexdigest()
    
    # Generate storage key
    file_ext = file.filename.split('.')[-1] if '.' in file.filename else 'bin'
    storage_key = f"statements/{user.id}/{card_id}/{checksum}.{file_ext}"
    
    # TODO: Upload to MinIO/S3
    # await storage_service.upload_file(storage_key, content, content_type)
    
    # Create artifact record
    from datetime import datetime, timedelta
    artifact = SourceArtifact(
        user_id=user.id,
        original_filename=file.filename,
        storage_key=storage_key,
        mime_type=content_type,
        file_size_bytes=file_size,
        checksum_sha256=checksum,
        delete_after=datetime.utcnow() + timedelta(days=settings.statement_retention_days)
    )
    
    db.add(artifact)
    await db.commit()
    await db.refresh(artifact)
    
    # TODO: Queue parsing job
    # await queue_parsing_job(artifact.id, card_id)
    
    return UploadResponse(
        artifact_id=artifact.id,
        filename=file.filename,
        status="pending",
        message="File uploaded successfully. Processing will begin shortly.",
        estimated_processing_time_seconds=30
    )


@router.get(
    "/{artifact_id}/status",
    response_model=ProcessingStatusResponse,
    summary="Get processing status",
    description="Check the processing status of an uploaded statement."
)
async def get_upload_status(
    artifact_id: UUID,
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Get the processing status of an uploaded statement."""
    query = select(SourceArtifact).where(
        SourceArtifact.id == artifact_id,
        SourceArtifact.user_id == user.id
    )
    result = await db.execute(query)
    artifact = result.scalar_one_or_none()
    
    if not artifact:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Upload not found"
        )
    
    # Calculate progress based on status
    progress = None
    if artifact.processing_status == "pending":
        progress = 0
    elif artifact.processing_status == "processing":
        progress = 50  # Estimate
    elif artifact.processing_status == "completed":
        progress = 100
    
    return ProcessingStatusResponse(
        artifact_id=artifact.id,
        status=artifact.processing_status,
        progress_percent=progress,
        bill_id=None,  # TODO: Link to bill if completed
        error=artifact.processing_error,
        created_at=artifact.uploaded_at,
        updated_at=None  # TODO: Track update time
    )
