"""
Cleanup tasks for CLIO.
"""
from datetime import datetime, timedelta
import structlog

from celery import shared_task
from app.worker import celery_app
from app.db.session import get_db_session
from app.models.models import SourceArtifact, AuditLog
from app.services.storage_service import get_storage_service
from app.core.config import get_settings

logger = structlog.get_logger()
settings = get_settings()


@celery_app.task
def cleanup_expired_statements():
    """
    Delete expired statement files.
    Runs daily to enforce data retention policy.
    """
    logger.info("starting_cleanup_task")
    
    try:
        with get_db_session() as db:
            # Find expired artifacts
            expired = db.query(SourceArtifact).filter(
                SourceArtifact.delete_after <= datetime.utcnow(),
                SourceArtifact.deleted_at.is_(None)
            ).all()
            
            storage = get_storage_service()
            deleted_count = 0
            
            for artifact in expired:
                try:
                    # Delete from storage
                    storage.delete_file(artifact.storage_key)
                    
                    # Mark as deleted in DB
                    artifact.deleted_at = datetime.utcnow()
                    deleted_count += 1
                    
                    logger.info("deleted_expired_statement", artifact_id=str(artifact.id))
                    
                except Exception as e:
                    logger.error("failed_to_delete_statement", 
                               artifact_id=str(artifact.id), error=str(e))
            
            db.commit()
            
            logger.info("cleanup_task_completed", deleted_count=deleted_count)
            return {"status": "success", "deleted_count": deleted_count}
            
    except Exception as e:
        logger.error("cleanup_task_failed", error=str(e))
        return {"status": "error", "message": str(e)}


@celery_app.task
def cleanup_expired_audit_logs():
    """
    Delete expired audit logs.
    Runs weekly to enforce audit log retention policy.
    """
    logger.info("starting_audit_log_cleanup")
    
    try:
        with get_db_session() as db:
            # Find expired audit logs
            expired = db.query(AuditLog).filter(
                AuditLog.delete_after <= datetime.utcnow()
            ).all()
            
            deleted_count = len(expired)
            
            for log in expired:
                db.delete(log)
            
            db.commit()
            
            logger.info("audit_log_cleanup_completed", deleted_count=deleted_count)
            return {"status": "success", "deleted_count": deleted_count}
            
    except Exception as e:
        logger.error("audit_log_cleanup_failed", error=str(e))
        return {"status": "error", "message": str(e)}
