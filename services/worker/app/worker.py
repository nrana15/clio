"""
Simplified Celery application configuration for CLIO.
"""
import os
from celery import Celery
import structlog

logger = structlog.get_logger()

# Get configuration from environment
broker_url = os.getenv("CELERY_BROKER_URL", "redis://redis:6379/1")
result_backend = os.getenv("CELERY_RESULT_BACKEND", "redis://redis:6379/2")

# Create Celery app - simple and direct
celery_app = Celery("clio")

# Configure directly
celery_app.conf.broker_url = broker_url
celery_app.conf.result_backend = result_backend
celery_app.conf.task_serializer = "json"
celery_app.conf.accept_content = ["json"]
celery_app.conf.result_serializer = "json"
celery_app.conf.timezone = "Asia/Taipei"
celery_app.conf.enable_utc = True
celery_app.conf.task_track_started = True
celery_app.conf.result_expires = 3600

# Autodiscover tasks
celery_app.autodiscover_tasks(["app.tasks"])

# Try to import tasks
try:
    from app.tasks import parse_statement, cleanup, notifications
    logger.info("celery_tasks_loaded")
except ImportError as e:
    logger.warning(f"some_tasks_not_loaded: {e}")


@celery_app.task(bind=True)
def debug_task(self):
    """Debug task to verify Celery is working."""
    print(f"Request: {self.request!r}")
    return "OK"
