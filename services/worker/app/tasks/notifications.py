"""
Notification Celery tasks
"""
import asyncio
from celery import shared_task
from celery.utils.log import get_task_logger

from app.services.notification_scheduler import get_notification_scheduler
from app.db.session import async_session

logger = get_task_logger(__name__)


@shared_task(bind=True, max_retries=3)
def send_due_notifications(self):
    """
    Send due notifications.
    Run every 5 minutes via beat schedule.
    """
    logger.info("Starting notification dispatch")
    
    async def _send():
        async with async_session() as db:
            scheduler = get_notification_scheduler()
            
            # Get pending notifications
            pending = await scheduler.get_pending_notifications(db, limit=100)
            
            sent_count = 0
            failed_count = 0
            
            for schedule in pending:
                try:
                    success = await scheduler.send_notification(db, schedule)
                    if success:
                        sent_count += 1
                    else:
                        failed_count += 1
                except Exception as e:
                    logger.error(f"Failed to send notification {schedule.id}: {e}")
                    failed_count += 1
            
            logger.info(f"Notifications sent: {sent_count}, failed: {failed_count}")
            return {"sent": sent_count, "failed": failed_count}
    
    try:
        result = asyncio.run(_send())
        return result
    except Exception as exc:
        logger.error(f"Notification task failed: {exc}")
        raise self.retry(exc=exc, countdown=60)


@shared_task
def schedule_bill_notifications(bill_id: str, user_id: str):
    """
    Schedule notifications for a new bill.
    Called after bill creation.
    """
    async def _schedule():
        async with async_session() as db:
            scheduler = get_notification_scheduler()
            schedules = await scheduler.schedule_notifications_for_bill(db, bill_id, user_id)
            return len(schedules)
    
    count = asyncio.run(_schedule())
    logger.info(f"Scheduled {count} notifications for bill {bill_id}")
    return count


@shared_task
def cancel_notifications_for_bill(bill_id: str):
    """
    Cancel all pending notifications for a bill.
    Called when bill is marked as paid.
    """
    async def _cancel():
        async with async_session() as db:
            scheduler = get_notification_scheduler()
            count = await scheduler.cancel_bill_notifications(db, bill_id)
            return count
    
    count = asyncio.run(_cancel())
    logger.info(f"Cancelled {count} notifications for bill {bill_id}")
    return count
