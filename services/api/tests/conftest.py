"""
Pytest configuration for CLIO API tests
"""
import pytest
import sys
import os

# Add the app directory to the path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'app'))


def pytest_configure(config):
    """Configure pytest markers."""
    config.addinivalue_line(
        "markers", "integration: marks tests as integration tests (slow)"
    )
    config.addinivalue_line(
        "markers", "unit: marks tests as unit tests (fast)"
    )


@pytest.fixture(autouse=True)
def set_test_environment(monkeypatch):
    """Set environment variables for testing."""
    monkeypatch.setenv("ENVIRONMENT", "testing")
    monkeypatch.setenv("DEBUG", "false")
    monkeypatch.setenv("DATABASE_URL", "postgresql+asyncpg://clio:clio@localhost:5432/clio_test")
    monkeypatch.setenv("JWT_SECRET", "test-secret-key-for-testing-only")
