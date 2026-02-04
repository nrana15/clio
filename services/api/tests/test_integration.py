"""
Integration tests for CLIO API
"""
import pytest
import asyncio
from datetime import datetime, timedelta
from httpx import AsyncClient, ASGITransport
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker
from jose import jwt

# Import the FastAPI app
from app.main import app
from app.core.config import get_settings
from app.db.session import get_db
from app.models.models import Base, User, Card, Bill, BillStatus

settings = get_settings()

# Test database URL
TEST_DATABASE_URL = "postgresql+asyncpg://clio:clio@localhost:5432/clio_test"

# Create test engine
engine = create_async_engine(TEST_DATABASE_URL, echo=False)
TestingSessionLocal = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)


async def override_get_db():
    """Override database dependency for testing."""
    async with TestingSessionLocal() as session:
        yield session


app.dependency_overrides[get_db] = override_get_db


@pytest.fixture(scope="session")
def event_loop():
    """Create an instance of the default event loop for the test session."""
    loop = asyncio.get_event_loop_policy().new_event_loop()
    yield loop
    loop.close()


@pytest.fixture(autouse=True)
async def setup_database():
    """Create and drop test database tables."""
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)


@pytest.fixture
async def client():
    """Create an async test client."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


@pytest.fixture
async def test_user():
    """Create a test user."""
    async with TestingSessionLocal() as db:
        user = User(
            phone_number="+886912345678",
            email="test@example.com",
            full_name="Test User",
            is_verified=True,
            is_active=True
        )
        db.add(user)
        await db.commit()
        await db.refresh(user)
        return user


@pytest.fixture
def auth_headers(test_user):
    """Generate authentication headers for test user."""
    from app.services.auth_service import AuthService
    tokens = AuthService.create_token_pair(str(test_user.id))
    return {"Authorization": f"Bearer {tokens.access_token}"}


class TestHealthEndpoints:
    """Tests for health check endpoints."""
    
    async def test_health_check(self, client):
        """Test the health check endpoint."""
        response = await client.get("/healthz")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "healthy"
    
    async def test_readiness_check(self, client):
        """Test the readiness check endpoint."""
        response = await client.get("/readyz")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "ready"


class TestAuthentication:
    """Tests for authentication endpoints."""
    
    async def test_auth_start_with_phone(self, client):
        """Test starting authentication with phone number."""
        response = await client.post(
            "/api/v1/auth/start",
            json={"phone_number": "+886912345678"}
        )
        assert response.status_code == 200
        data = response.json()
        assert "message" in data
        assert "expires_in_seconds" in data
    
    async def test_auth_start_with_email(self, client):
        """Test starting authentication with email."""
        response = await client.post(
            "/api/v1/auth/start",
            json={"email": "test@example.com"}
        )
        assert response.status_code == 200
        data = response.json()
        assert "message" in data
    
    async def test_auth_start_without_credentials(self, client):
        """Test starting authentication without credentials fails."""
        response = await client.post(
            "/api/v1/auth/start",
            json={}
        )
        assert response.status_code == 400
    
    async def test_protected_endpoint_without_auth(self, client):
        """Test that protected endpoints require authentication."""
        response = await client.get("/api/v1/cards")
        assert response.status_code == 401
        data = response.json()
        assert data["error"] == "Authentication Error"


class TestCards:
    """Tests for card management endpoints."""
    
    async def test_create_card(self, client, auth_headers):
        """Test creating a new card."""
        response = await client.post(
            "/api/v1/cards",
            headers=auth_headers,
            json={
                "issuer_bank": "CTBC",
                "last_four": "1234",
                "nickname": "Test Card",
                "card_color": "#1E3A8A"
            }
        )
        assert response.status_code == 201
        data = response.json()
        assert data["issuer_bank"] == "CTBC"
        assert data["last_four"] == "1234"
        assert data["nickname"] == "Test Card"
    
    async def test_create_card_unsupported_bank(self, client, auth_headers):
        """Test creating a card with unsupported bank fails."""
        response = await client.post(
            "/api/v1/cards",
            headers=auth_headers,
            json={
                "issuer_bank": "Unknown Bank",
                "last_four": "1234"
            }
        )
        assert response.status_code == 400
    
    async def test_create_card_invalid_last_four(self, client, auth_headers):
        """Test creating a card with invalid last four digits fails."""
        response = await client.post(
            "/api/v1/cards",
            headers=auth_headers,
            json={
                "issuer_bank": "CTBC",
                "last_four": "123"  # Only 3 digits
            }
        )
        assert response.status_code == 422
    
    async def test_list_cards(self, client, auth_headers):
        """Test listing cards."""
        # First create a card
        await client.post(
            "/api/v1/cards",
            headers=auth_headers,
            json={
                "issuer_bank": "CTBC",
                "last_four": "1234"
            }
        )
        
        response = await client.get("/api/v1/cards", headers=auth_headers)
        assert response.status_code == 200
        data = response.json()
        assert "cards" in data
        assert len(data["cards"]) >= 1
    
    async def test_get_card(self, client, auth_headers):
        """Test getting a specific card."""
        # Create a card first
        create_response = await client.post(
            "/api/v1/cards",
            headers=auth_headers,
            json={
                "issuer_bank": "CTBC",
                "last_four": "5678"
            }
        )
        card_id = create_response.json()["id"]
        
        response = await client.get(f"/api/v1/cards/{card_id}", headers=auth_headers)
        assert response.status_code == 200
        data = response.json()
        assert data["last_four"] == "5678"
    
    async def test_update_card(self, client, auth_headers):
        """Test updating a card."""
        # Create a card first
        create_response = await client.post(
            "/api/v1/cards",
            headers=auth_headers,
            json={
                "issuer_bank": "CTBC",
                "last_four": "9999"
            }
        )
        card_id = create_response.json()["id"]
        
        response = await client.patch(
            f"/api/v1/cards/{card_id}",
            headers=auth_headers,
            json={"nickname": "Updated Card"}
        )
        assert response.status_code == 200
        data = response.json()
        assert data["nickname"] == "Updated Card"
    
    async def test_delete_card(self, client, auth_headers):
        """Test deleting (soft delete) a card."""
        # Create a card first
        create_response = await client.post(
            "/api/v1/cards",
            headers=auth_headers,
            json={
                "issuer_bank": "CTBC",
                "last_four": "0000"
            }
        )
        card_id = create_response.json()["id"]
        
        response = await client.delete(f"/api/v1/cards/{card_id}", headers=auth_headers)
        assert response.status_code == 204


class TestBills:
    """Tests for bill management endpoints."""
    
    async def test_get_dashboard(self, client, auth_headers):
        """Test getting dashboard data."""
        response = await client.get("/api/v1/bills/dashboard", headers=auth_headers)
        assert response.status_code == 200
        data = response.json()
        assert "bills_by_status" in data
        assert "upcoming_bills" in data
    
    async def test_list_bills(self, client, auth_headers):
        """Test listing bills."""
        response = await client.get("/api/v1/bills", headers=auth_headers)
        assert response.status_code == 200
        data = response.json()
        assert "bills" in data
        assert "upcoming_total" in data
        assert "overdue_count" in data
    
    async def test_confirm_bill_paid(self, client, auth_headers, test_user):
        """Test confirming a bill as paid."""
        # First create a card
        card_response = await client.post(
            "/api/v1/cards",
            headers=auth_headers,
            json={
                "issuer_bank": "CTBC",
                "last_four": "1234"
            }
        )
        card_id = card_response.json()["id"]
        
        # Create a bill directly in database
        async with TestingSessionLocal() as db:
            from decimal import Decimal
            from uuid import UUID
            bill = Bill(
                user_id=test_user.id,
                card_id=UUID(card_id),
                statement_date=datetime.now().date(),
                statement_month=datetime.now().strftime("%Y-%m"),
                due_date=datetime.now().date() + timedelta(days=15),
                total_amount_due=Decimal("1000.00"),
                extraction_confidence=Decimal("0.95"),
                status=BillStatus.UNPAID
            )
            db.add(bill)
            await db.commit()
            await db.refresh(bill)
            bill_id = str(bill.id)
        
        response = await client.post(
            f"/api/v1/bills/{bill_id}/confirm-paid",
            headers=auth_headers,
            json={"confirmed": True}
        )
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "paid_confirmed"


class TestRateLimiting:
    """Tests for rate limiting."""
    
    async def test_rate_limit_headers(self, client):
        """Test that rate limit headers are present."""
        response = await client.get("/healthz")
        assert response.status_code == 200
        assert "X-RateLimit-Limit" in response.headers
        assert "X-RateLimit-Remaining" in response.headers
        assert "X-RateLimit-Reset" in response.headers
    
    async def test_request_id_header(self, client):
        """Test that request ID header is present."""
        response = await client.get("/healthz")
        assert response.status_code == 200
        assert "X-Request-ID" in response.headers


class TestUserProfile:
    """Tests for user profile endpoints."""
    
    async def test_get_user_profile(self, client, auth_headers, test_user):
        """Test getting user profile."""
        response = await client.get("/api/v1/auth/me", headers=auth_headers)
        assert response.status_code == 200
        data = response.json()
        assert data["id"] == str(test_user.id)
        assert data["phone_number"] == test_user.phone_number
    
    async def test_update_user_profile(self, client, auth_headers):
        """Test updating user profile."""
        response = await client.patch(
            "/api/v1/auth/me",
            headers=auth_headers,
            json={
                "full_name": "Updated Name",
                "enable_biometric_lock": True
            }
        )
        assert response.status_code == 200
        data = response.json()
        assert data["full_name"] == "Updated Name"
        assert data["enable_biometric_lock"] == True


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
