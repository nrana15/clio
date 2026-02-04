"""
CLIO API Configuration
"""
from pydantic_settings import BaseSettings
from functools import lru_cache
from typing import Optional


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""
    
    # Environment
    environment: str = "development"
    debug: bool = False
    
    # Database
    database_url: str = "postgresql+asyncpg://clio:clio@localhost:5432/clio"
    
    # Redis
    redis_url: str = "redis://localhost:6379/0"
    
    # JWT
    jwt_secret: str = "change-this-in-production"
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 30
    refresh_token_expire_days: int = 7
    
    # MinIO / S3
    minio_endpoint: str = "localhost:9000"
    minio_access_key: str = "minioadmin"
    minio_secret_key: str = "minioadmin"
    minio_bucket: str = "clio-statements"
    minio_use_ssl: bool = False
    
    # OTP
    otp_length: int = 6
    otp_expire_minutes: int = 5
    
    # Data Retention
    statement_retention_days: int = 90
    audit_log_retention_days: int = 365
    
    # File Upload
    max_upload_size_mb: int = 10
    allowed_upload_types: str = "application/pdf,image/jpeg,image/png,image/heic"
    
    # Email Webhook
    email_webhook_secret: Optional[str] = None
    
    # Push Notifications
    fcm_server_key: Optional[str] = None
    
    # Prometheus Metrics
    enable_metrics: bool = True
    metrics_port: int = 9090
    
    # Celery
    celery_broker_url: Optional[str] = None
    celery_result_backend: Optional[str] = None
    
    @property
    def celery_config(self) -> dict:
        broker = self.celery_broker_url or self.redis_url
        backend = self.celery_result_backend or self.redis_url
        return {
            "broker_url": broker,
            "result_backend": backend,
        }
    
    @property
    def allowed_upload_mime_types(self) -> list[str]:
        return [t.strip() for t in self.allowed_upload_types.split(",")]
    
    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"
        case_sensitive = False


@lru_cache()
def get_settings() -> Settings:
    """Get cached settings instance."""
    return Settings()
