"""
MinIO/S3 storage service for file operations.
"""
from io import BytesIO
from typing import Optional
import structlog

from minio import Minio
from minio.error import S3Error

from app.core.config import get_settings

logger = structlog.get_logger()


class StorageService:
    """Handle file storage operations with MinIO/S3."""
    
    def __init__(self):
        self.settings = get_settings()
        self.client = self._create_client()
        self.logger = logger.bind(service="storage")
    
    def _create_client(self) -> Minio:
        """Create MinIO client."""
        return Minio(
            self.settings.minio_endpoint,
            access_key=self.settings.minio_access_key,
            secret_key=self.settings.minio_secret_key,
            secure=self.settings.minio_use_ssl
        )
    
    def upload_file(self, key: str, data: bytes, content_type: str = "application/octet-stream") -> bool:
        """Upload file to storage."""
        try:
            from minio.commonconfig import Tags
            
            # Ensure bucket exists
            if not self.client.bucket_exists(self.settings.minio_bucket):
                self.client.make_bucket(self.settings.minio_bucket)
            
            # Upload
            self.client.put_object(
                bucket_name=self.settings.minio_bucket,
                object_name=key,
                data=BytesIO(data),
                length=len(data),
                content_type=content_type
            )
            
            self.logger.info("file_uploaded", key=key, size=len(data))
            return True
            
        except S3Error as e:
            self.logger.error("upload_failed", key=key, error=str(e))
            return False
    
    def download_file(self, key: str) -> Optional[bytes]:
        """Download file from storage."""
        try:
            response = self.client.get_object(
                bucket_name=self.settings.minio_bucket,
                object_name=key
            )
            data = response.read()
            response.close()
            response.release_conn()
            
            self.logger.info("file_downloaded", key=key, size=len(data))
            return data
            
        except S3Error as e:
            self.logger.error("download_failed", key=key, error=str(e))
            return None
    
    def delete_file(self, key: str) -> bool:
        """Delete file from storage."""
        try:
            self.client.remove_object(
                bucket_name=self.settings.minio_bucket,
                object_name=key
            )
            self.logger.info("file_deleted", key=key)
            return True
            
        except S3Error as e:
            self.logger.error("delete_failed", key=key, error=str(e))
            return False
    
    def get_file_url(self, key: str, expiry: int = 3600) -> Optional[str]:
        """Get presigned URL for file access."""
        try:
            url = self.client.presigned_get_object(
                bucket_name=self.settings.minio_bucket,
                object_name=key,
                expires=expiry
            )
            return url
            
        except S3Error as e:
            self.logger.error("url_generation_failed", key=key, error=str(e))
            return None


# Singleton instance
_storage_service = None

def get_storage_service() -> StorageService:
    """Get storage service singleton."""
    global _storage_service
    if _storage_service is None:
        _storage_service = StorageService()
    return _storage_service
