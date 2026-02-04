# CLIO - Credit Card Bill Aggregator

<p align="center">
  <img src="docs/assets/logo.png" alt="CLIO Logo" width="200">
</p>

<p align="center">
  A premium fintech-grade mobile app for aggregating and managing credit card bills.
</p>

<p align="center">
  <a href="https://github.com/yourusername/clio/actions"><img src="https://github.com/yourusername/clio/workflows/CLIO%20CI/CD%20Pipeline/badge.svg" alt="CI"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="License"></a>
  <a href="docs/ROADMAP.md"><img src="https://img.shields.io/badge/Roadmap-100%25-green.svg" alt="Roadmap"></a>
</p>

---

## Overview

CLIO is a **view-only** credit card bill aggregator that helps users track their credit card bills across multiple banks without executing payments or storing sensitive card data.

### Key Features

- 📱 **Cross-Platform Mobile App** - Built with Flutter for iOS and Android
- 🔐 **Bank-Grade Security** - JWT auth, biometric lock, secure storage
- 🔔 **Smart Notifications** - Push notifications for due dates via FCM
- 📧 **Email Integration** - Forward statements via email webhook
- 🤖 **AI-Powered OCR** - Automatic bill extraction from PDF/images
- 📊 **Dashboard** - Visual overview of upcoming bills and totals

### Supported Banks

- CTBC (中國信託)
- Cathay United Bank (國泰世華)
- Taishin Bank (台新)

---

## Tech Stack

| Component | Technology |
|-----------|------------|
| Mobile App | Flutter 3.16+ |
| Backend API | Python 3.11 + FastAPI |
| Database | PostgreSQL 15 |
| Queue / Cache | Redis 7 |
| Object Storage | MinIO (S3-compatible) |
| Parsing Worker | Python Celery |
| Push Notifications | Firebase Cloud Messaging |
| Monitoring | Prometheus + Grafana |
| CI/CD | GitHub Actions |

---

## Project Structure

```
clio/
├── apps/
│   └── mobile/              # Flutter app
├── services/
│   ├── api/                 # FastAPI backend
│   └── worker/              # Celery parsing worker
├── infra/                   # Docker Compose, configs
├── docs/                    # Documentation
│   ├── ROADMAP.md          # Project roadmap
│   ├── DEPLOYMENT.md       # Production deployment guide
│   └── SECURITY.md         # Security documentation
├── .github/workflows/       # CI/CD pipelines
├── .env.example            # Environment template
└── README.md
```

---

## Quick Start

### Prerequisites

- Docker & Docker Compose
- Flutter SDK 3.16+ (for mobile development)
- Python 3.11+ (for local backend development)
- Git

### One-Command Setup

```bash
# 1. Clone the repository
git clone https://github.com/yourusername/clio.git
cd clio

# 2. Copy environment file
cp .env.example .env

# 3. Start all infrastructure services
docker-compose -f infra/docker-compose.yml up -d

# 4. Run database migrations
cd services/api && alembic upgrade head

# 5. Start the API
cd services/api && uvicorn app.main:app --reload

# 6. Start the worker (in another terminal)
cd services/worker && celery -A app.tasks worker --loglevel=info

# 7. Run mobile app (in another terminal)
cd apps/mobile && flutter run
```

### API Documentation

Once the API is running, access the interactive documentation:

- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

---

## Development

### Backend Development

```bash
cd services/api

# Install dependencies
pip install -r requirements-dev.txt

# Run linting
black .
flake8 .
mypy app

# Run tests
pytest --cov=app --cov-report=html

# Run with hot reload
uvicorn app.main:app --reload
```

### Mobile Development

```bash
cd apps/mobile

# Get dependencies
flutter pub get

# Generate code (if using code generation)
flutter pub run build_runner build

# Run on device
flutter run

# Run tests
flutter test

# Build release APK
flutter build apk --release
```

### Worker Development

```bash
cd services/worker

# Run Celery worker
celery -A app.tasks worker --loglevel=info -c 4

# Run Celery beat (scheduler)
celery -A app.tasks beat --loglevel=info
```

---

## API Endpoints

### Authentication
- `POST /api/v1/auth/start` - Send OTP
- `POST /api/v1/auth/verify` - Verify OTP & get tokens
- `POST /api/v1/auth/refresh` - Refresh access token
- `POST /api/v1/auth/logout` - Revoke tokens

### Cards
- `GET /api/v1/cards` - List cards
- `POST /api/v1/cards` - Add card
- `PATCH /api/v1/cards/{id}` - Update card
- `DELETE /api/v1/cards/{id}` - Delete card

### Bills
- `GET /api/v1/bills/dashboard` - Dashboard data
- `GET /api/v1/bills` - List bills
- `GET /api/v1/bills/{id}` - Get bill details
- `PATCH /api/v1/bills/{id}` - Update bill
- `POST /api/v1/bills/{id}/confirm-paid` - Mark as paid

### Uploads
- `POST /api/v1/uploads/statement` - Upload PDF/image
- `GET /api/v1/uploads/status/{id}` - Check processing status

### Notifications
- `POST /api/v1/notifications/register-device` - Register FCM token
- `GET /api/v1/notifications/devices` - List devices
- `GET /api/v1/notifications/history` - Notification history

### Webhooks
- `POST /api/v1/bills/from-email-webhook` - Email webhook

### Health & Monitoring
- `GET /healthz` - Liveness probe
- `GET /readyz` - Readiness probe
- `GET /metrics` - Prometheus metrics

---

## Security

CLIO implements multiple layers of security:

### Data Protection
- ✅ No full card numbers (PAN), CVV, or expiry stored
- ✅ Only last 4 digits of cards stored
- ✅ Encrypted data at rest
- ✅ TLS 1.2+ for all connections

### Authentication
- ✅ OTP-based authentication
- ✅ JWT with short expiry
- ✅ Refresh token rotation
- ✅ Rate limiting on auth endpoints

### Mobile Security
- ✅ Biometric app lock
- ✅ Secure storage (Keychain/Keystore)
- ✅ Root/jailbreak detection
- ✅ Certificate pinning
- ✅ Screenshot protection

### Infrastructure
- ✅ PII log scrubbing
- ✅ Request ID tracing
- ✅ Audit logging
- ✅ Automated data retention

See [SECURITY.md](docs/SECURITY.md) for detailed security documentation.

---

## Deployment

### Production Deployment

See [DEPLOYMENT.md](docs/DEPLOYMENT.md) for comprehensive deployment instructions.

Quick production deployment:

```bash
# 1. Configure environment
cp .env.example .env.production
# Edit .env.production with your production values

# 2. Deploy with Docker Compose
docker-compose -f infra/docker-compose.prod.yml up -d

# 3. Run migrations
docker-compose -f infra/docker-compose.prod.yml exec api alembic upgrade head
```

### CI/CD Pipeline

The GitHub Actions workflow includes:
- ✅ Python linting (black, flake8, mypy)
- ✅ Backend tests with pytest
- ✅ Flutter build and tests
- ✅ Docker image build and push
- ✅ Security scanning with Trivy
- ✅ Automated deployment to staging/production

---

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `ENVIRONMENT` | Environment (development/production) | `development` |
| `DATABASE_URL` | PostgreSQL connection string | - |
| `REDIS_URL` | Redis connection string | - |
| `JWT_SECRET` | Secret key for JWT signing | - |
| `MINIO_ENDPOINT` | MinIO/S3 endpoint | - |
| `FCM_SERVER_KEY` | Firebase Cloud Messaging server key | - |
| `EMAIL_WEBHOOK_SECRET` | Secret for email webhook verification | - |
| `ENABLE_METRICS` | Enable Prometheus metrics | `true` |

See [.env.example](.env.example) for all available options.

---

## Monitoring

CLIO includes built-in monitoring with Prometheus metrics:

- HTTP request count and latency
- Active connections
- Database connection pool stats
- Custom business metrics

Access metrics at `/metrics` endpoint.

---

## Roadmap

| Phase | Status | Description |
|-------|--------|-------------|
| Phase 1: Foundation | ✅ Complete | Core API and mobile scaffold |
| Phase 2: Parsing Engine | ✅ Complete | OCR and bank parsers |
| Phase 3: Mobile UI | ✅ Complete | All screens and components |
| Phase 4: Security | ✅ Complete | Auth, encryption, security features |
| Phase 5: Notifications | ✅ Complete | FCM push notifications |
| Phase 6: CI/CD & Production | ✅ Complete | GitHub Actions, deployment |

See [ROADMAP.md](docs/ROADMAP.md) for detailed roadmap.

---

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## Acknowledgments

- Design inspired by CRED and Zerodha
- Icons from Material Design and Phosphor Icons
- OCR powered by Tesseract

---

<p align="center">
  Built with ❤️ by the CLIO team
</p>
