"""
Email webhook endpoint for receiving bill statements via email
"""
import base64
import hashlib
import hmac
import uuid
from datetime import datetime, timedelta
from typing import Optional, List

from fastapi import APIRouter, Depends, HTTPException, status, Header, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.models.models import User, SourceArtifact
from app.schemas.schemas import EmailWebhookPayload, EmailWebhookResponse
from app.core.config import get_settings
from app.services.storage_service import get_storage_service

settings = get_settings()
router = APIRouter()


def verify_webhook_secret(payload: bytes, signature: str, secret: str) -> bool:
    """Verify webhook signature using HMAC-SHA256."""
    expected = hmac.new(
        secret.encode(),
        payload,
        hashlib.sha256
    ).hexdigest()
    return hmac.compare_digest(expected, signature)


def extract_user_from_email(to_address: str) -> Optional[str]:
    """
    Extract user ID from email address.
    Expected format: user+{uuid}@clio.app or similar
    """
    try:
        # Parse email for user identifier
        local_part = to_address.split("@")[0]
        
        # Check for plus addressing: user+{uuid}@domain.com
        if "+" in local_part:
            identifier = local_part.split("+")[1]
            return identifier
        
        return None
    except Exception:
        return None


@router.post(
    "/from-email-webhook",
    response_model=EmailWebhookResponse,
    summary="Receive bill statements via email",
    description="Webhook endpoint for receiving email with bill statement attachments.",
    status_code=status.HTTP_202_ACCEPTED
)
async def email_webhook(
    request: Request,
    payload: EmailWebhookPayload,
    db: AsyncSession = Depends(get_db),
    x_webhook_signature: Optional[str] = Header(None, alias="X-Webhook-Signature")
):
    """
    Receive bill statements via email webhook.
    
    Security:
    - Requires X-Webhook-Signature header with HMAC-SHA256 signature
    - Signature is computed using the configured webhook secret
    """
    # Verify webhook signature
    if settings.email_webhook_secret:
        if not x_webhook_signature:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Missing webhook signature"
            )
        
        body = await request.body()
        if not verify_webhook_secret(body, x_webhook_signature, settings.email_webhook_secret):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid webhook signature"
            )
    
    # Extract user from email address
    user_identifier = extract_user_from_email(payload.to)
    
    if not user_identifier:
        return EmailWebhookResponse(
            accepted=False,
            message="Could not identify user from email address",
            artifact_ids=[]
        )
    
    # Find user by identifier (could be UUID or other identifier)
    from sqlalchemy import select, or_
    
    user_query = select(User).where(
        or_(
            str(User.id) == user_identifier,
            User.email == payload.to,
            User.email == user_identifier
        )
    )
    result = await db.execute(user_query)
    user = result.scalar_one_or_none()
    
    if not user:
        return EmailWebhookResponse(
            accepted=False,
            message="User not found",
            artifact_ids=[]
        )
    
    # Process attachments
    storage = get_storage_service()
    artifact_ids = []
    
    for attachment in payload.attachments:
        filename = attachment.get("filename", "unknown")
        content_type = attachment.get("content_type", "application/octet-stream")
        content_base64 = attachment.get("content", "")
        
        # Validate file type
        if content_type not in settings.allowed_upload_mime_types:
            if not any(filename.lower().endswith(ext) for ext in [".pdf", ".jpg", ".jpeg", ".png"]):
                continue
        
        try:
            # Decode base64 content
            file_content = base64.b64decode(content_base64)
            
            # Check file size
            if len(file_content) > settings.max_upload_size_mb * 1024 * 1024:
                continue
            
            # Generate storage key
            artifact_id = uuid.uuid4()
            timestamp = datetime.utcnow().strftime("%Y/%m/%d")
            storage_key = f"emails/{user.id}/{timestamp}/{artifact_id}_{filename}"
            
            # Upload to storage
            await storage.upload_file(
                key=storage_key,
                data=file_content,
                content_type=content_type
            )
            
            # Create artifact record
            artifact = SourceArtifact(
                id=artifact_id,
                user_id=user.id,
                original_filename=filename,
                storage_key=storage_key,
                mime_type=content_type,
                file_size_bytes=len(file_content),
                processing_status="pending",
                checksum_sha256=hashlib.sha256(file_content).hexdigest(),
                delete_after=datetime.utcnow() + timedelta(days=settings.statement_retention_days)
            )
            
            db.add(artifact)
            artifact_ids.append(artifact_id)
            
        except Exception as e:
            # Log error but continue processing other attachments
            print(f"[EMAIL_WEBHOOK] Error processing attachment {filename}: {e}")
            continue
    
    await db.commit()
    
    # TODO: Queue processing jobs for artifacts
    # for artifact_id in artifact_ids:
    #     await queue_parsing_job(artifact_id)
    
    return EmailWebhookResponse(
        accepted=len(artifact_ids) > 0,
        message=f"Accepted {len(artifact_ids)} attachments for processing",
        artifact_ids=artifact_ids
    )


@router.post(
    "/from-email-webhook/sendgrid",
    response_model=EmailWebhookResponse,
    summary="Receive emails via SendGrid webhook",
    description="Webhook endpoint optimized for SendGrid inbound parse."
)
async def sendgrid_webhook(
    request: Request,
    db: AsyncSession = Depends(get_db)
):
    """Receive emails via SendGrid Inbound Parse webhook."""
    # Parse SendGrid multipart form data
    form = await request.form()
    
    to = form.get("to", "")
    from_email = form.get("from", "")
    subject = form.get("subject", "")
    text = form.get("text", "")
    
    # SendGrid attaches files as UploadFile
    attachments = []
    for key in form.keys():
        if key.startswith("attachment-"):
            file = form[key]
            content = await file.read()
            attachments.append({
                "filename": file.filename,
                "content_type": file.content_type,
                "content": base64.b64encode(content).decode()
            })
    
    # Convert to standard payload
    payload = EmailWebhookPayload(
        to=to,
        from_email=from_email,
        subject=subject,
        body_text=text,
        attachments=attachments,
        received_at=datetime.utcnow()
    )
    
    # Process with main handler
    return await email_webhook(request, payload, db)
