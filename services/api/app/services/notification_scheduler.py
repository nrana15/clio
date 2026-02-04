"""
Notification scheduling service
"""
from datetime import datetime, timedelta, date
from typing import List, Optional

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_

from app.models.models import Bill, BillStatus, NotificationSchedule
from app.models.device_token import DeviceToken
from app.services.fcm_service import get_fcm_service


class NotificationScheduler:
    """Service for scheduling and sending bill reminders."""
    
    # Notification schedule relative to due date (in days)
    NOTIFICATION_SCHEDULE = {
        "due_soon": 3,      # 3 days before due date
        "due_today": 0,     # On due date
        "overdue": -1,      # Day after due date
    }
    
    async def schedule_notifications_for_bill(
        self,
        db: AsyncSession,
        bill_id: str,
        user_id: str
    ) -> List[NotificationSchedule]:
        """
        Create notification schedules for a new bill.
        
        Args:
            db: Database session
            bill_id: The bill ID
            user_id: The user ID
            
        Returns:
            List of created notification schedules
        """
        # Get bill details
        result = await db.execute(
            select(Bill).where(Bill.id == bill_id)
        )
        bill = result.scalar_one_or_none()
        
        if not bill:
            return []
        
        if bill.status == BillStatus.PAID_CONFIRMED:
            return []
        
        schedules = []
        
        for notification_type, days_before in self.NOTIFICATION_SCHEDULE.items():
            scheduled_date = bill.due_date - timedelta(days=days_before)
            
            # Skip if scheduled date is in the past
            if scheduled_date < date.today():
                continue
            
            # Schedule for 9:00 AM local time
            scheduled_at = datetime.combine(scheduled_date, datetime.min.time()) + timedelta(hours=9)
            
            schedule = NotificationSchedule(
                user_id=user_id,
                bill_id=bill_id,
                scheduled_at=scheduled_at,
                notification_type=notification_type,
                send_status="pending"
            )
            db.add(schedule)
            schedules.append(schedule)
        
        await db.commit()
        return schedules
    
    async def get_pending_notifications(
        self,
        db: AsyncSession,
        limit: int = 100
    ) -> List[NotificationSchedule]:
        """
        Get notifications that are due to be sent.
        
        Args:
            db: Database session
            limit: Maximum number of notifications to fetch
            
        Returns:
            List of pending notification schedules
        """
        now = datetime.utcnow()
        
        query = select(NotificationSchedule).where(
            and_(
                NotificationSchedule.send_status == "pending",
                NotificationSchedule.scheduled_at <= now
            )
        ).limit(limit)
        
        result = await db.execute(query)
        return list(result.scalars().all())
    
    async def send_notification(
        self,
        db: AsyncSession,
        schedule: NotificationSchedule
    ) -> bool:
        """
        Send a scheduled notification.
        
        Args:
            db: Database session
            schedule: The notification schedule to send
            
        Returns:
            True if sent successfully, False otherwise
        """
        # Get bill details for personalized message
        result = await db.execute(
            select(Bill).where(Bill.id == schedule.bill_id)
        )
        bill = result.scalar_one_or_none()
        
        if not bill or bill.status == BillStatus.PAID_CONFIRMED:
            # Mark as cancelled if bill is paid
            schedule.send_status = "cancelled"
            await db.commit()
            return False
        
        # Generate message based on notification type
        title, body = self._generate_message(schedule.notification_type, bill)
        
        # Send via FCM
        fcm_service = get_fcm_service()
        results = await fcm_service.send_to_user(
            db=db,
            user_id=str(schedule.user_id),
            title=title,
            body=body,
            data={
                "bill_id": str(bill.id),
                "type": schedule.notification_type,
                "due_date": bill.due_date.isoformat()
            },
            notification_type=schedule.notification_type
        )
        
        # Update schedule status
        if any(r["success"] for r in results):
            schedule.send_status = "sent"
            schedule.sent_at = datetime.utcnow()
            success = True
        else:
            schedule.send_status = "failed"
            schedule.error_message = "Failed to send to any device"
            success = False
        
        await db.commit()
        return success
    
    def _generate_message(self, notification_type: str, bill) -> tuple[str, str]:
        """Generate notification title and body."""
        card_name = bill.card.display_name if bill.card else "Credit Card"
        amount = f"${float(bill.total_amount_due):,.2f}"
        
        if notification_type == "due_soon":
            title = f"💳 Bill Due in 3 Days"
            body = f"Your {card_name} bill of {amount} is due in 3 days."
        elif notification_type == "due_today":
            title = f"⚠️ Bill Due Today"
            body = f"Your {card_name} bill of {amount} is due today. Don't forget to pay!"
        elif notification_type == "overdue":
            title = f"🔴 Bill Overdue"
            body = f"Your {card_name} bill of {amount} is now overdue. Please pay immediately."
        else:
            title = f"💳 Payment Reminder"
            body = f"You have a bill payment coming up for {card_name}."
        
        return title, body
    
    async def cancel_bill_notifications(
        self,
        db: AsyncSession,
        bill_id: str
    ) -> int:
        """
        Cancel all pending notifications for a bill.
        
        Returns:
            Number of cancelled notifications
        """
        query = select(NotificationSchedule).where(
            and_(
                NotificationSchedule.bill_id == bill_id,
                NotificationSchedule.send_status == "pending"
            )
        )
        result = await db.execute(query)
        schedules = result.scalars().all()
        
        cancelled_count = 0
        for schedule in schedules:
            schedule.send_status = "cancelled"
            cancelled_count += 1
        
        await db.commit()
        return cancelled_count


# Singleton instance
_scheduler: Optional[NotificationScheduler] = None


def get_notification_scheduler() -> NotificationScheduler:
    """Get or create notification scheduler singleton."""
    global _scheduler
    if _scheduler is None:
        _scheduler = NotificationScheduler()
    return _scheduler
