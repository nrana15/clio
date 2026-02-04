"""
Simplified Celery application configuration for CLIO.
"""
import os
from celery import Celery
from celery.signals import task_prerun, task_postrun, task_failure
import structlog

# Get settings from environment or use defaults
BROKER_URL = os.getenv("CELERY_BROKER_URL", "redis://redis:6379/1")
RESULT_BACKEND = os.getenv("CELERY_RESULT_BACKEND", "redis://redis:6379/2")

logger = structlog.get_logger()

# Create Celery app
celery_app = Celery(
    "clio",
    broker=BROKER_URL,
    backend=RESULT_BACKEND,
    include=[
        "app.tasks.parse_statement",
        "app.tasks.cleanup",
        "app.tasks.notifications",
    ]
)

# Celery configuration
celery_app.conf.update(
    # Task settings
    task_serializer="json",
    accept_content=["json"],
    result_serializer="json",
    timezone="Asia/Taipei",
    enable_utc=True,
    
    # Task execution
    task_track_started=True,
    task_time_limit=300,
    task_soft_time_limit=240,
    
    # Result backend
    result_expires=3600,
    result_backend_always_retry=True,
    
    # Worker settings
    worker_prefetch_multiplier=1,
    worker_max_tasks_per_child=100,
    
    # Queue configuration
    task_default_queue="default",
)


# Task signals for monitoring
@task_prerun.connect
def task_prerun_handler(task_id, task, args, kwargs, **extras):
    """Log task start."""
    logger.info(
        "task_started",
        task_id=task_id,
        task_name=task.name,
    )


@task_postrun.connect
def task_postrun_handler(task_id, task, args, kwargs, retval, state, **extras):
    """Log task completion."""
    logger.info(
        "task_completed",
        task_id=task_id,
        task_name=task.name,
        state=state,
    )


@task_failure.connect
def task_failure_handler(task_id, exception, args, kwargs, traceback, einfo, **extras):
    """Log task failure."""
    logger.error(
        "task_failed",
        task_id=task_id,
        exception=str(exception),
    )


# Import tasks to register them
try:
    from app.tasks import parse_statement, cleanup, notifications
except ImportError as e:
    logger.warning(f"Could not import some tasks: {e}")
