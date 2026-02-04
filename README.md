# CLIO - Credit Card Bill Aggregator

A premium fintech-grade mobile app for aggregating and managing credit card bills.

## Overview

CLIO is a **view-only** credit card bill aggregator that helps users track their credit card bills across multiple banks without executing payments or storing sensitive card data.

## Supported Banks (Initial)

- CTBC (中國信託)
- Cathay United Bank (國泰世華)
- Taishin Bank (台新)

## Tech Stack

| Component | Technology |
|-----------|------------|
| Mobile App | Flutter (iOS + Android) |
| Backend API | Python FastAPI |
| Database | PostgreSQL |
| Queue / Cache | Redis |
| Object Storage | MinIO (S3-compatible) |
| Parsing Worker | Python (Celery) |
| Local Dev | Docker Compose |
| CI | GitHub Actions |

## Project Structure

```
clio/
├── apps/
│   └── mobile/              # Flutter app
├── services/
│   ├── api/                 # FastAPI backend
│   └── worker/              # Celery parsing worker
├── infra/                   # Docker Compose, configs
├── docs/                    # Architecture, security, API docs
├── fixtures/                # Sample statements (redacted)
├── scripts/                 # Maintenance scripts
├── .github/workflows/       # CI/CD
└── README.md
```

## Quick Start

### Prerequisites

- Docker & Docker Compose
- Flutter SDK (for mobile development)
- Python 3.12+ (for local backend development)

### One-Command Setup

```bash
# Start all infrastructure services
docker-compose -f infra/docker-compose.yml up -d

# Run database migrations
cd services/api && alembic upgrade head

# Start the API
cd services/api && uvicorn app.main:app --reload

# Start the worker
cd services/worker && celery -A app.worker worker --loglevel=info

# Run mobile app
cd apps/mobile && flutter run
```

## Development

See individual README files in each directory for detailed setup instructions.

## Security

- No full card numbers (PAN), CVV, or expiry stored
- Encrypted data at rest
- HTTPS only with certificate pinning
- Biometric app lock option
- Root/jailbreak detection
- Data retention policies enforced

## License

MIT License - Personal Project
