"""
FCM Push Notification Service
"""
import json
from typing import Optional, List
import aiohttp

from app.core.config import get_settings
from app.models.device_token import DeviceToken, NotificationLog
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

settings = get_settings()


class FCMService:
    """Firebase Cloud Messaging service for push notifications."""
    
    FCM_API_URL = "https://fcm.googleapis.com/fcm/send"
    
    def __init__(self):
        self.server_key = settings.fcm_server_key
    
    async def send_notification(
        self,
        device_token: str,
        title: str,
        body: str,
        data: Optional[dict] = None,
        notification_type: str = "general"
    ) -> dict:
        """
        Send a push notification via FCM.
        
        Args:
            device_token: FCM device token
            title: Notification title
            body: Notification body
            data: Optional data payload
            notification_type: Type of notification
            
        Returns:
            dict with success status and message_id or error
        """
        if not self.server_key:
            return {
                "success": False,
                "error": "FCM server key not configured",
                "message_id": None
            }
        
        headers = {
            "Authorization": f"key={self.server_key}",
            "Content-Type": "application/json"
        }
        
        payload = {
            "to": device_token,
            "notification": {
                "title": title,
                "body": body,
                "sound": "default",
                "badge": 1,
                "click_action": "FLUTTER_NOTIFICATION_CLICK"
            },
            "data": data or {},
            "priority": "high"
        }
        
        # Add notification type to data
        payload["data"]["type"] = notification_type
        
        try:
            async with aiohttp.ClientSession() as session:
                async with session.post(
                    self.FCM_API_URL,
                    headers=headers,
                    json=payload,
                    timeout=aiohttp.ClientTimeout(total=30)
                ) as response:
                    result = await response.json()
                    
                    if response.status == 200 and result.get("success") == 1:
                        return {
                            "success": True,
                            "message_id": result.get("message_id"),
                            "error": None
                        }
                    else:
                        error = result.get("results", [{}])[0].get("error", "Unknown error")
                        return {
                            "success": False,
                            "message_id": None,
                            "error": error
                        }
        except Exception as e:
            return {
                "success": False,
                "message_id": None,
                "error": str(e)
            }
    
    async def send_to_user(
        self,
        db: AsyncSession,
        user_id: str,
        title: str,
        body: str,
        data: Optional[dict] = None,
        notification_type: str = "general"
    ) -> List[dict]:
        """
        Send notification to all active devices of a user.
        
        Returns:
            List of send results for each device
        """
        # Get all active device tokens for user
        query = select(DeviceToken).where(
            DeviceToken.user_id == user_id,
            DeviceToken.is_active == "active"
        )
        result = await db.execute(query)
        devices = result.scalars().all()
        
        results = []
        for device in devices:
            send_result = await self.send_notification(
                device_token=device.token,
                title=title,
                body=body,
                data=data,
                notification_type=notification_type
            )
            
            # Log the notification
            log = NotificationLog(
                user_id=user_id,
                notification_type=notification_type,
                title=title,
                body=body,
                device_token_id=device.id,
                status="sent" if send_result["success"] else "failed",
                error_message=send_result.get("error"),
                fcm_message_id=send_result.get("message_id")
            )
            db.add(log)
            
            results.append({
                "device_id": str(device.id),
                "success": send_result["success"],
                "error": send_result.get("error")
            })
        
        await db.commit()
        return results


# Singleton instance
_fcm_service: Optional[FCMService] = None


def get_fcm_service() -> FCMService:
    """Get or create FCM service singleton."""
    global _fcm_service
    if _fcm_service is None:
        _fcm_service = FCMService()
    return _fcm_service
