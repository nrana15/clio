# CLIO Roadmap

## Project Overview
**CLIO** — Credit Card Bill Aggregator (View-Only)
A premium fintech-grade mobile app for tracking credit card bills.

---

## Phase 1: Foundation ✅ COMPLETE
**Status:** Done (Feb 4, 2026)

### Backend API (FastAPI)
- [x] Project structure & Docker Compose
- [x] PostgreSQL database models
  - [x] Users (no PII storage)
  - [x] Cards (last4 only, no PAN/CVV/expiry)
  - [x] Bills with extraction confidence
  - [x] SourceArtifacts with retention
  - [x] NotificationSchedules
  - [x] AuditLogs
  - [x] OTPAttempts
- [x] Pydantic schemas (20+ request/response models)
- [x] Authentication service (OTP + JWT)
- [x] API endpoints:
  - [x] POST /auth/start — Send OTP
  - [x] POST /auth/verify — Verify OTP & get tokens
  - [x] POST /auth/refresh — Refresh access token
  - [x] POST /auth/logout — Revoke tokens
  - [x] POST /cards — Add credit card
  - [x] GET /cards — List cards
  - [x] PATCH /cards/{id} — Update card
  - [x] DELETE /cards/{id} — Remove card
  - [x] GET /bills/dashboard — Dashboard data
  - [x] GET /bills — List bills
  - [x] GET /bills/{id} — Get bill details
  - [x] PATCH /bills/{id} — Edit extracted data
  - [x] POST /bills/{id}/confirm-paid — Mark as paid
  - [x] POST /uploads/statement — Upload PDF/image
  - [x] GET /uploads/status/{id} — Check processing
  - [x] GET /reminders/upcoming — Get reminders
  - [x] GET /healthz, /readyz — Health checks

### Mobile App (Flutter)
- [x] Project scaffold with clean architecture
- [x] Design system (light/dark themes)
- [x] Typography & spacing tokens
- [x] Color palette (inspired by CRED/Zerodha)
- [x] State management (BLoC pattern)
- [x] Pubspec with all dependencies

### Infrastructure
- [x] Docker Compose with:
  - [x] PostgreSQL
  - [x] Redis
  - [x] MinIO (S3-compatible)
  - [x] API service
  - [x] Worker service (Celery)
  - [x] Beat scheduler
- [x] Environment configuration (.env.example)
- [x] README with setup instructions

**Lines of Code:** ~2,200
**Files:** 21

---

## Phase 2: Parsing Engine ✅ COMPLETE
**Status:** Done (Feb 4, 2026)

### Celery Worker
- [x] PDF text extraction (PyMuPDF)
- [x] Image OCR (Tesseract)
- [x] Bank-specific parsers:
  - [x] CTBC (中國信託)
  - [x] Cathay United Bank (國泰世華)
  - [x] Taishin Bank (台新)
- [x] Generic fallback parser
- [x] Confidence scoring algorithm
- [x] Field normalization
- [x] Error handling & retry logic

### Processing Pipeline
- [x] Upload to MinIO
- [x] Virus scan stub
- [x] Queue parsing job
- [x] Extract: statement date, due date, total due, minimum due
- [x] Calculate confidence score
- [x] Mark review_required if confidence < 0.80
- [x] Create Bill record
- [x] Trigger notifications

---

## Phase 3: Mobile UI Screens ✅ COMPLETE
**Status:** Done (Feb 4, 2026)

### Authentication Flow
- [x] Splash screen with animation
- [x] Phone/Email input screen
- [x] OTP verification screen
- [x] Biometric setup (optional)

### Main App Screens
- [x] Bottom navigation (Dashboard, Cards, Upload, Settings)
- [x] **Dashboard Screen:**
  - [x] Hero card (next due bill)
  - [x] Upcoming bills list
  - [x] Pull-to-refresh
  - [x] Empty states
- [x] **Cards Screen:**
  - [x] List of credit cards
  - [x] Add card flow
  - [x] Edit/delete card
  - [x] Bank logos
- [x] **Upload Screen:**
  - [x] File picker (PDF/image)
  - [x] Camera capture
  - [x] Upload progress
  - [x] Processing status
- [x] **Bill Detail Screen:**
  - [x] Extracted data display
  - [x] Edit mode (if low confidence)
  - [x] Confirm paid button
  - [x] Delete option
- [x] **Settings Screen:**
  - [x] Profile
  - [x] Biometric lock toggle
  - [x] Notification preferences
  - [x] Data retention info
  - [x] Privacy policy
  - [x] Logout

### UI Components
- [x] BillCard widget
- [x] BankCardTile widget
- [x] Primary/Secondary buttons
- [x] Status chips (Due Soon, Overdue, Paid)
- [x] Skeleton loaders
- [x] Bottom sheets
- [x] Snackbar notifications

---

## Phase 4: Security & Polish ✅ COMPLETE
**Status:** Done (Feb 4, 2026)

### Mobile Security
- [x] Secure storage (Keychain/Keystore)
- [x] Biometric app lock
- [x] Hide sensitive UI in app switcher
- [x] Root/jailbreak detection
- [x] Certificate pinning
- [x] No sensitive logs

### Backend Security
- [x] JWT middleware for all protected routes
- [x] Row-level authorization
- [x] Rate limiting (auth endpoints)
- [x] PII log scrubbing
- [x] Request ID tracing
- [x] CORS configuration
- [x] Input validation

### Data Retention
- [x] Automated cleanup job
- [x] Delete raw statements after 90 days
- [x] Audit log rotation (365 days)

---

## Phase 5: Push Notifications ✅ COMPLETE
**Status:** Done (Feb 4, 2026)

### Backend
- [x] POST /notifications/register-device endpoint
- [x] FCM integration for push notifications
- [x] DeviceToken and NotificationLog models
- [x] Notification scheduling service
- [x] Send reminder notifications (due_soon, due_today, overdue)
- [x] Notification history endpoint

### Mobile
- [x] FCM setup and token registration
- [x] Firebase configuration (Android/iOS/Web)
- [x] Push notification handlers (foreground/background/terminated)
- [x] Local notifications as fallback
- [x] Notification scheduling with timezone support

---

## Phase 6: CI/CD & Production ✅ COMPLETE
**Status:** Done (Feb 4, 2026)

### GitHub Actions Workflow (.github/workflows/ci.yml)
- [x] Lint Python (black, flake8, mypy)
- [x] Run backend tests with pytest
- [x] Build Flutter app (APK + Web)
- [x] Run Flutter tests
- [x] Integration tests with Docker Compose
- [x] Security scanning with Trivy
- [x] Docker build and push to GitHub Container Registry
- [x] Staging and Production deployment jobs

### Email Webhook Endpoint
- [x] POST /bills/from-email-webhook endpoint
- [x] HMAC-SHA256 webhook signature verification
- [x] Parse email with attachments (multipart/base64)
- [x] Store attachments and queue for processing
- [x] SendGrid webhook compatibility
- [x] Security with webhook secret

### Production Prep
- [x] Environment-specific configs (.env.production)
- [x] SSL/TLS notes in deployment guide
- [x] Prometheus metrics endpoint (/metrics)
- [x] Health check improvements with dependency checks
- [x] Request/response metrics tracking
- [x] Deployment guide with Docker Compose

---

## Current Status Summary

| Phase | Status | Progress |
|-------|--------|----------|
| Phase 1: Foundation | ✅ Complete | 100% |
| Phase 2: Parsing Engine | ✅ Complete | 100% |
| Phase 3: Mobile UI | ✅ Complete | 100% |
| Phase 4: Security | ✅ Complete | 100% |
| Phase 5: Notifications | ✅ Complete | 100% |
| Phase 6: CI/CD & Production | ✅ Complete | 100% |

**Overall Progress:** 100%
**MVP Status:** ✅ COMPLETE

---

## Lines of Code Summary

| Component | Files | Lines of Code |
|-----------|-------|---------------|
| Backend API | 35 | ~4,500 |
| Mobile App | 28 | ~3,800 |
| Worker | 15 | ~2,200 |
| Infrastructure | 8 | ~800 |
| Tests | 12 | ~1,500 |
| **Total** | **98** | **~12,800** |

---

## Key Features Delivered

### Core Functionality
- ✅ OTP-based authentication
- ✅ JWT token management
- ✅ Credit card management
- ✅ PDF/Image statement upload
- ✅ OCR and bill extraction
- ✅ Dashboard with upcoming bills
- ✅ Bill payment tracking

### Security
- ✅ Biometric authentication
- ✅ Secure storage
- ✅ Rate limiting
- ✅ Request ID tracing
- ✅ PII data handling

### Notifications
- ✅ Push notifications via FCM
- ✅ Local notification fallback
- ✅ Bill reminder scheduling
- ✅ Due date alerts (3 days, today, overdue)

### DevOps
- ✅ CI/CD pipeline
- ✅ Docker containerization
- ✅ Prometheus metrics
- ✅ Health checks
- ✅ Deployment guide

---

## Next Steps (Post-MVP)

1. **Beta Testing**
   - Invite beta testers
   - Gather feedback
   - Bug fixes

2. **App Store Release**
   - iOS App Store submission
   - Google Play Store submission

3. **Future Enhancements**
   - Multi-currency support
   - Spending analytics
   - Export to CSV/PDF
   - Dark mode refinements
   - Widget support

---

*Project completed on Feb 4, 2026*
