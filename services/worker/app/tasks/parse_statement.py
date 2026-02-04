"""
Celery task for parsing credit card statements.
"""
from datetime import datetime, timedelta
from decimal import Decimal
import uuid
import structlog

from celery import shared_task
from celery.exceptions import MaxRetriesExceededError

from app.worker import celery_app
from app.db.session import get_db_session
from app.models.models import SourceArtifact, Bill, Card, BillStatus
from app.services.pdf_service import get_pdf_service
from app.services.ocr_service import get_ocr_service
from app.services.storage_service import get_storage_service
from app.core.config import get_settings

# Import parsers
from app.parsers import CTBCParser, CathayUnitedParser, TaishinParser, GenericParser

logger = structlog.get_logger()
settings = get_settings()


# Parser registry
PARSERS = [
    CTBCParser(),
    CathayUnitedParser(),
    TaishinParser(),
]


@celery_app.task(bind=True, max_retries=3)
def parse_statement_task(self, artifact_id: str):
    """
    Celery task to parse a credit card statement.
    
    Args:
        artifact_id: UUID of the SourceArtifact to parse
    """
    logger.info("starting_parse_task", artifact_id=artifact_id)
    
    try:
        with get_db_session() as db:
            # Get artifact
            artifact = db.query(SourceArtifact).filter(
                SourceArtifact.id == uuid.UUID(artifact_id)
            ).first()
            
            if not artifact:
                logger.error("artifact_not_found", artifact_id=artifact_id)
                return {"status": "error", "message": "Artifact not found"}
            
            # Update status to processing
            artifact.processing_status = "processing"
            db.commit()
            
            # Download file from storage
            storage = get_storage_service()
            file_content = storage.download_file(artifact.storage_key)
            
            if not file_content:
                raise Exception("Failed to download file from storage")
            
            # Extract text based on file type
            if artifact.mime_type == "application/pdf":
                text_content = extract_from_pdf(file_content)
            elif artifact.mime_type.startswith("image/"):
                text_content = extract_from_image(file_content)
            else:
                raise Exception(f"Unsupported file type: {artifact.mime_type}")
            
            # Parse bill data
            parsed_bill = parse_bill_data(text_content, artifact.card_id)
            
            # Create Bill record
            bill = Bill(
                user_id=artifact.user_id,
                card_id=uuid.UUID(artifact.card_id) if artifact.card_id else None,
                source_artifact_id=artifact.id,
                statement_date=parsed_bill.statement_date,
                statement_month=parsed_bill.statement_date.strftime("%Y-%m"),
                due_date=parsed_bill.due_date,
                total_amount_due=parsed_bill.total_amount_due,
                minimum_due=parsed_bill.minimum_due,
                currency=parsed_bill.currency,
                extraction_confidence=parsed_bill.confidence_score,
                requires_review=parsed_bill.confidence_score < settings.confidence_threshold,
                raw_extraction_data=parsed_bill.raw_fields,
                status=BillStatus.PENDING_REVIEW,
            )
            
            db.add(bill)
            
            # Update artifact status
            artifact.processing_status = "completed"
            db.commit()
            
            logger.info(
                "parse_task_completed",
                artifact_id=artifact_id,
                bill_id=str(bill.id),
                confidence=parsed_bill.confidence_score
            )
            
            return {
                "status": "success",
                "bill_id": str(bill.id),
                "confidence": parsed_bill.confidence_score,
                "requires_review": bill.requires_review
            }
            
    except Exception as e:
        logger.error("parse_task_failed", artifact_id=artifact_id, error=str(e))
        
        # Update artifact status
        try:
            with get_db_session() as db:
                artifact = db.query(SourceArtifact).filter(
                    SourceArtifact.id == uuid.UUID(artifact_id)
                ).first()
                if artifact:
                    artifact.processing_status = "failed"
                    artifact.processing_error = str(e)
                    db.commit()
        except:
            pass
        
        # Retry logic
        if self.request.retries < 3:
            logger.info("retrying_parse_task", artifact_id=artifact_id, retry_count=self.request.retries + 1)
            raise self.retry(countdown=60)
        
        return {"status": "error", "message": str(e)}


def extract_from_pdf(file_content: bytes) -> str:
    """Extract text from PDF file."""
    pdf_service = get_pdf_service()
    
    # Try PDF text extraction first
    result = pdf_service.extract_text(file_content)
    
    if result["success"] and len(result["text"]) > 100:
        return result["text"]
    
    # Fallback to OCR for scanned PDFs
    ocr_service = get_ocr_service()
    if ocr_service.is_scanned_pdf(file_content):
        ocr_result = ocr_service.extract_from_pdf(file_content)
        if ocr_result["success"]:
            return ocr_result["text"]
    
    return result["text"]


def extract_from_image(file_content: bytes) -> str:
    """Extract text from image file using OCR."""
    ocr_service = get_ocr_service()
    result = ocr_service.extract_from_image(file_content)
    
    if result["success"]:
        return result["text"]
    
    raise Exception(f"OCR failed: {result['error']}")


def parse_bill_data(text: str, card_id: str = None):
    """
    Parse bill data from extracted text.
    
    Returns:
        ParsedBill object
    """
    # Try bank-specific parsers first
    for parser in PARSERS:
        if parser.can_parse(text):
            logger.info("using_bank_parser", parser=parser.BANK_NAME)
            return parser.parse(text)
    
    # Fallback to generic parser
    logger.info("using_generic_parser")
    generic = GenericParser()
    return generic.parse(text)
