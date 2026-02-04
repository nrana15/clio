"""
Core configuration for the worker service.
"""
from pydantic_settings import BaseSettings
from functools import lru_cache
from typing import Optional


class Settings(BaseSettings):
    """Worker settings loaded from environment variables."""
    
    # Environment
    environment: str = "development"
    debug: bool = False
    
    # Database (synchronous for Celery workers)
    database_url: str = "postgresql+psycopg2://clio:clio@localhost:5432/clio"
    
    # Redis
    redis_url: str = "redis://localhost:6379/0"
    celery_broker_url: str = "redis://localhost:6379/1"
    celery_result_backend: str = "redis://localhost:6379/2"
    
    # MinIO / S3
    minio_endpoint: str = "localhost:9000"
    minio_access_key: str = "minioadmin"
    minio_secret_key: str = "minioadmin"
    minio_bucket: str = "clio-statements"
    minio_use_ssl: bool = False
    
    # Data Retention
    statement_retention_days: int = 90
    audit_log_retention_days: int = 365
    
    # Processing
    max_upload_size_mb: int = 10
    confidence_threshold: float = 0.80  # Below this requires review
    
    # OCR
    ocr_language: str = "chi_tra+chi_sim+eng"  # Traditional Chinese, Simplified, English
    
    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"
        case_sensitive = False


@lru_cache()
def get_settings() -> Settings:
    """Get cached settings instance."""
    return Settings()
