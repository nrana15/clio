"""
Celery tasks configuration
"""
from celery import Celery
from app.core.config import get_settings

settings = get_settings()

celery_app = Celery(
    "clio",
    broker=settings.celery_config["broker_url"],
    backend=settings.celery_config["result_backend"],
    include=[
        "app.tasks.parse_statement",
        "app.tasks.cleanup",
        "app.tasks.notifications",
    ]
)

celery_app.conf.update(
    task_serializer="json",
    accept_content=["json"],
    result_serializer="json",
    timezone="Asia/Taipei",
    enable_utc=True,
    task_track_started=True,
    task_time_limit=300,  # 5 minutes
    worker_prefetch_multiplier=1,
    worker_max_tasks_per_child=1000,
)

# Beat schedule
celery_app.conf.beat_schedule = {
    "cleanup-old-artifacts": {
        "task": "app.tasks.cleanup.cleanup_old_artifacts",
        "schedule": 86400.0,  # Daily
    },
    "send-due-notifications": {
        "task": "app.tasks.notifications.send_due_notifications",
        "schedule": 300.0,  # Every 5 minutes
    },
}
