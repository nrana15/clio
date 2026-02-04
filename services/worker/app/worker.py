"""
Absolute minimal Celery configuration - ZERO imports from app
"""
import os
from celery import Celery

# Get config from environment ONLY
broker_url = os.getenv("CELERY_BROKER_URL", "redis://redis:6379/1")
result_backend = os.getenv("CELERY_RESULT_BACKEND", "redis://redis:6379/2")

# Create Celery app
app = Celery("clio")

# Configure
app.conf.broker_url = broker_url
app.conf.result_backend = result_backend
app.conf.task_serializer = "json"
app.conf.accept_content = ["json"]
app.conf.result_serializer = "json"
app.conf.timezone = "Asia/Taipei"
app.conf.enable_utc = True

# Export for celery command
# This makes 'app.worker:app' work
celery_app = app


@app.task
def add(x, y):
    """Simple test task."""
    return x + y


@app.task
def parse_statement_task(artifact_id):
    """Parse statement - placeholder for now."""
    print(f"Would parse artifact: {artifact_id}")
    return {"status": "ok", "artifact_id": artifact_id}
