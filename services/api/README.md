# CLIO API

FastAPI-based REST API for the CLIO Credit Card Bill Aggregator.

## Features

- **Authentication**: OTP-based authentication with JWT tokens
- **Security**: Rate limiting, request ID tracing, CORS protection
- **Bill Management**: CRUD operations for bills, cards, and reminders
- **File Upload**: Support for PDF/image uploads with MinIO storage
- **Async**: Full async/await support for high performance

## Tech Stack

- **Framework**: FastAPI 0.109+
- **Database**: PostgreSQL 15+ with asyncpg
- **ORM**: SQLAlchemy 2.0+
- **Cache/Queue**: Redis
- **Object Storage**: MinIO (S3-compatible)
- **Testing**: pytest with async support

## Quick Start

### Prerequisites

- Python 3.12+
- PostgreSQL 15+
- Redis 7+
- MinIO (optional for local dev)

### Installation

```bash
# Create virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Set environment variables
cp .env.example .env
# Edit .env with your configuration

# Run database migrations
alembic upgrade head

# Start development server
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

### Environment Variables

```bash
# Application
ENVIRONMENT=development
DEBUG=true

# Database
DATABASE_URL=postgresql+asyncpg://clio:clio@localhost:5432/clio

# Redis
REDIS_URL=redis://localhost:6379/0

# JWT
JWT_SECRET=your-super-secret-key-min-32-characters
JWT_ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30
REFRESH_TOKEN_EXPIRE_DAYS=7

# MinIO / S3
MINIO_ENDPOINT=localhost:9000
MINIO_ACCESS_KEY=minioadmin
MINIO_SECRET_KEY=minioadmin
MINIO_BUCKET=clio-statements
MINIO_USE_SSL=false

# OTP
OTP_LENGTH=6
OTP_EXPIRE_MINUTES=5

# File Upload
MAX_UPLOAD_SIZE_MB=10
ALLOWED_UPLOAD_TYPES=application/pdf,image/jpeg,image/png,image/heic
```

## API Endpoints

### Health Checks

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/healthz` | Liveness probe |
| GET | `/readyz` | Readiness probe (checks DB, Redis) |

### Authentication

| Method | Endpoint | Description | Auth Required |
|--------|----------|-------------|---------------|
| POST | `/api/v1/auth/start` | Send OTP to phone/email | No |
| POST | `/api/v1/auth/verify` | Verify OTP, get tokens | No |
| POST | `/api/v1/auth/refresh` | Refresh access token | No |
| POST | `/api/v1/auth/logout` | Revoke refresh token | Yes |
| GET | `/api/v1/auth/me` | Get user profile | Yes |
| PATCH | `/api/v1/auth/me` | Update user profile | Yes |
| DELETE | `/api/v1/auth/me` | Delete account | Yes |

### Cards

| Method | Endpoint | Description | Auth Required |
|--------|----------|-------------|---------------|
| POST | `/api/v1/cards` | Add a new card | Yes |
| GET | `/api/v1/cards` | List all cards | Yes |
| GET | `/api/v1/cards/{id}` | Get card details | Yes |
| PATCH | `/api/v1/cards/{id}` | Update card | Yes |
| DELETE | `/api/v1/cards/{id}` | Delete card (soft) | Yes |

### Bills

| Method | Endpoint | Description | Auth Required |
|--------|----------|-------------|---------------|
| GET | `/api/v1/bills/dashboard` | Get dashboard data | Yes |
| GET | `/api/v1/bills` | List all bills | Yes |
| GET | `/api/v1/bills/{id}` | Get bill details | Yes |
| PATCH | `/api/v1/bills/{id}` | Update bill | Yes |
| POST | `/api/v1/bills/{id}/confirm-paid` | Mark bill as paid | Yes |

### Uploads

| Method | Endpoint | Description | Auth Required |
|--------|----------|-------------|---------------|
| POST | `/api/v1/uploads` | Upload statement | Yes |
| GET | `/api/v1/uploads/{id}/status` | Check processing status | Yes |

### Reminders

| Method | Endpoint | Description | Auth Required |
|--------|----------|-------------|---------------|
| GET | `/api/v1/reminders` | List reminders | Yes |
| GET | `/api/v1/reminders/upcoming` | Get upcoming reminders | Yes |
| POST | `/api/v1/reminders/{id}/cancel` | Cancel reminder | Yes |

## Request/Response Examples

### Authentication

**Start Authentication:**
```bash
curl -X POST http://localhost:8000/api/v1/auth/start \
  -H "Content-Type: application/json" \
  -d '{"phone_number": "+886912345678"}'
```

Response:
```json
{
  "message": "OTP sent successfully",
  "expires_in_seconds": 300,
  "otp_code": "123456"  // Only in development
}
```

**Verify OTP:**
```bash
curl -X POST http://localhost:8000/api/v1/auth/verify \
  -H "Content-Type: application/json" \
  -d '{
    "phone_number": "+886912345678",
    "otp_code": "123456"
  }'
```

Response:
```json
{
  "user": {
    "id": "uuid",
    "phone_number": "+886912345678",
    "full_name": null
  },
  "tokens": {
    "access_token": "eyJhbGciOiJIUzI1NiIs...",
    "refresh_token": "eyJhbGciOiJIUzI1NiIs...",
    "token_type": "bearer",
    "expires_in": 1800
  }
}
```

### Cards

**Create Card:**
```bash
curl -X POST http://localhost:8000/api/v1/cards \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "issuer_bank": "CTBC",
    "last_four": "1234",
    "nickname": "My Card",
    "card_color": "#1E3A8A"
  }'
```

### Bills

**Get Dashboard:**
```bash
curl http://localhost:8000/api/v1/bills/dashboard \
  -H "Authorization: Bearer <token>"
```

Response:
```json
{
  "next_due_bill": {
    "id": "uuid",
    "card": {...},
    "due_date": "2024-02-15",
    "total_amount_due": "5000.00",
    "days_until_due": 10
  },
  "upcoming_bills": [...],
  "total_upcoming_amount": "15000.00",
  "bills_by_status": {
    "pending_review": 2,
    "unpaid": 5,
    "paid_confirmed": 10
  }
}
```

## Security Features

### Authentication

- **JWT Tokens**: Access tokens expire in 30 minutes, refresh tokens in 7 days
- **OTP**: 6-digit codes expire in 5 minutes
- **Token Revocation**: Refresh tokens can be revoked on logout

### Rate Limiting

| Tier | Requests/Window | Burst |
|------|-----------------|-------|
| Anonymous | 20/60s | 5 |
| Authenticated | 100/60s | 10 |
| Premium | 1000/60s | 50 |

Rate limit headers are included in all responses:
- `X-RateLimit-Limit`: Maximum requests allowed
- `X-RateLimit-Remaining`: Remaining requests in window
- `X-RateLimit-Reset`: Unix timestamp when limit resets

### Request Tracing

All requests include:
- `X-Request-ID`: Unique request identifier for tracing
- `X-Response-Time`: Response time in milliseconds

### CORS

Configured for:
- Development: `localhost:3000`, `localhost:8080`, `localhost:55352`
- Production: `https://clio.app`, `https://api.clio.app`

## Testing

### Run All Tests

```bash
# Set test database
export DATABASE_URL=postgresql+asyncpg://clio:clio@localhost:5432/clio_test

# Run all tests
pytest

# Run with coverage
pytest --cov=app --cov-report=html

# Run specific test file
pytest tests/test_integration.py -v

# Run specific test
pytest tests/test_parsers.py::TestCTBCParser::test_parse_full_statement -v
```

### Test Structure

```
tests/
├── conftest.py          # Shared fixtures and configuration
├── test_integration.py  # API integration tests
└── test_parsers.py      # Parser unit tests
```

## Database Schema

See `app/models/models.py` for complete schema definitions.

### Key Tables

- **users**: User accounts
- **cards**: Credit card metadata (non-sensitive)
- **bills**: Extracted bill data
- **source_artifacts**: Uploaded files
- **notification_schedules**: Reminder schedules
- **audit_logs**: Security audit trail
- **otp_attempts**: OTP verification attempts

## Development

### Code Structure

```
app/
├── api/
│   └── v1/
│       ├── endpoints/    # API route handlers
│       └── api.py        # Router aggregation
├── core/                 # Core utilities
│   ├── config.py         # Configuration
│   ├── security.py       # JWT authentication
│   ├── rate_limiter.py   # Rate limiting
│   └── request_id.py     # Request tracing
├── db/
│   └── session.py        # Database session
├── models/
│   └── models.py         # SQLAlchemy models
├── schemas/
│   └── schemas.py        # Pydantic schemas
└── services/
    └── auth_service.py   # Business logic
```

### Adding New Endpoints

1. Create route handler in `app/api/v1/endpoints/`
2. Use authentication dependency: `Depends(get_current_active_user)`
3. Add to router in `app/api/v1/api.py`
4. Write tests in `tests/`
5. Update this README

## License

MIT License - Personal Project
