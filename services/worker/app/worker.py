"""
Celery application configuration and task definitions for CLIO.
"""
import os
from celery import Celery
from celery.signals import task_prerun, task_postrun, task_failure
import structlog

from app.core.config import get_settings

settings = get_settings()
logger = structlog.get_logger()

# Create Celery app
celery_app = Celery(
    "clio",
    broker=settings.celery_broker_url,
    backend=settings.celery_result_backend,
    include=[
        "app.tasks.parse_statement",
        "app.tasks.cleanup",
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
    task_time_limit=300,  # 5 minutes max per task
    task_soft_time_limit=240,  # Soft limit at 4 minutes
    
    # Result backend
    result_expires=3600,  # Results expire after 1 hour
    result_backend_always_retry=True,
    
    # Worker settings
    worker_prefetch_multiplier=1,
    worker_max_tasks_per_child=100,
    
    # Queue configuration
    task_default_queue="default",
    task_queues={
        "default": {
            "exchange": "default",
            "routing_key": "default",
        },
        "parsing": {
            "exchange": "parsing",
            "routing_key": "parsing",
        },
        "cleanup": {
            "exchange": "cleanup",
            "routing_key": "cleanup",
        },
    },
    task_routes={
        "app.tasks.parse_statement.*": {"queue": "parsing"},
        "app.tasks.cleanup.*": {"queue": "cleanup"},
    },
    
    # Retry settings
    task_default_retry_delay=60,
    task_max_retries=3,
)


# Task signals for monitoring
@task_prerun.connect
def task_prerun_handler(task_id, task, args, kwargs, **extras):
    """Log task start."""
    logger.info(
        "task_started",
        task_id=task_id,
        task_name=task.name,
        args=str(args),
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
        args=str(args),
    )


# Import tasks to register them
from app.tasks import parse_statement, cleanup
