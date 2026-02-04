"""
Storage service for file operations (MinIO/S3)
"""
from typing import Optional, BinaryIO
import io

import aioboto3
from app.core.config import get_settings

settings = get_settings()


class StorageService:
    """Service for file storage operations using MinIO/S3."""
    
    def __init__(self):
        self.endpoint = settings.minio_endpoint
        self.access_key = settings.minio_access_key
        self.secret_key = settings.minio_secret_key
        self.bucket = settings.minio_bucket
        self.use_ssl = settings.minio_use_ssl
        
        self._session = aioboto3.Session()
    
    def _get_client(self):
        """Get S3 client."""
        return self._session.client(
            "s3",
            endpoint_url=f"{'https' if self.use_ssl else 'http'}://{self.endpoint}",
            aws_access_key_id=self.access_key,
            aws_secret_access_key=self.secret_key,
            region_name="us-east-1"
        )
    
    async def upload_file(
        self,
        key: str,
        data: bytes,
        content_type: str = "application/octet-stream"
    ) -> str:
        """
        Upload a file to storage.
        
        Args:
            key: Storage key/path
            data: File content as bytes
            content_type: MIME type
            
        Returns:
            Storage key
        """
        async with self._get_client() as client:
            await client.put_object(
                Bucket=self.bucket,
                Key=key,
                Body=data,
                ContentType=content_type
            )
        return key
    
    async def download_file(self, key: str) -> bytes:
        """
        Download a file from storage.
        
        Args:
            key: Storage key/path
            
        Returns:
            File content as bytes
        """
        async with self._get_client() as client:
            response = await client.get_object(Bucket=self.bucket, Key=key)
            async with response["Body"] as stream:
                return await stream.read()
    
    async def delete_file(self, key: str) -> bool:
        """
        Delete a file from storage.
        
        Args:
            key: Storage key/path
            
        Returns:
            True if deleted successfully
        """
        async with self._get_client() as client:
            await client.delete_object(Bucket=self.bucket, Key=key)
        return True
    
    async def file_exists(self, key: str) -> bool:
        """
        Check if a file exists in storage.
        
        Args:
            key: Storage key/path
            
        Returns:
            True if file exists
        """
        try:
            async with self._get_client() as client:
                await client.head_object(Bucket=self.bucket, Key=key)
            return True
        except Exception:
            return False
    
    async def generate_presigned_url(
        self,
        key: str,
        expiration: int = 3600
    ) -> str:
        """
        Generate a presigned URL for temporary access.
        
        Args:
            key: Storage key/path
            expiration: URL expiration time in seconds
            
        Returns:
            Presigned URL
        """
        async with self._get_client() as client:
            url = await client.generate_presigned_url(
                "get_object",
                Params={"Bucket": self.bucket, "Key": key},
                ExpiresIn=expiration
            )
        return url


# Singleton instance
_storage_service: Optional[StorageService] = None


def get_storage_service() -> StorageService:
    """Get or create storage service singleton."""
    global _storage_service
    if _storage_service is None:
        _storage_service = StorageService()
    return _storage_service
