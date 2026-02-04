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

## Phase 2: Parsing Engine 🔄 IN PROGRESS
**Status:** Building now

### Celery Worker
- [ ] PDF text extraction (PyMuPDF)
- [ ] Image OCR (Tesseract)
- [ ] Bank-specific parsers:
  - [ ] CTBC (中國信託)
  - [ ] Cathay United Bank (國泰世華)
  - [ ] Taishin Bank (台新)
- [ ] Generic fallback parser
- [ ] Confidence scoring algorithm
- [ ] Field normalization
- [ ] Error handling & retry logic

### Processing Pipeline
- [ ] Upload to MinIO
- [ ] Virus scan stub
- [ ] Queue parsing job
- [ ] Extract: statement date, due date, total due, minimum due
- [ ] Calculate confidence score
- [ ] Mark review_required if confidence < 0.80
- [ ] Create Bill record
- [ ] Trigger notifications

### Email Webhook
- [ ] POST /bills/from-email-webhook endpoint
- [ ] Parse email attachments
- [ ] Queue for processing

---

## Phase 3: Mobile UI Screens 🔄 UPCOMING

### Authentication Flow
- [ ] Splash screen with animation
- [ ] Phone/Email input screen
- [ ] OTP verification screen
- [ ] Biometric setup (optional)

### Main App Screens
- [ ] Bottom navigation (Dashboard, Cards, Upload, Settings)
- [ ] **Dashboard Screen:**
  - [ ] Hero card (next due bill)
  - [ ] Upcoming bills list
  - [ ] Pull-to-refresh
  - [ ] Empty states
- [ ] **Cards Screen:**
  - [ ] List of credit cards
  - [ ] Add card flow
  - [ ] Edit/delete card
  - [ ] Bank logos
- [ ] **Upload Screen:**
  - [ ] File picker (PDF/image)
  - [ ] Camera capture
  - [ ] Upload progress
  - [ ] Processing status
- [ ] **Bill Detail Screen:**
  - [ ] Extracted data display
  - [ ] Edit mode (if low confidence)
  - [ ] Confirm paid button
  - [ ] Delete option
- [ ] **Settings Screen:**
  - [ ] Profile
  - [ ] Biometric lock toggle
  - [ ] Notification preferences
  - [ ] Data retention info
  - [ ] Privacy policy
  - [ ] Logout

### UI Components
- [ ] BillCard widget
- [ ] BankCardTile widget
- [ ] Primary/Secondary buttons
- [ ] Status chips (Due Soon, Overdue, Paid)
- [ ] Skeleton loaders
- [ ] Bottom sheets
- [ ] Snackbar notifications

---

## Phase 4: Security & Polish 🔄 UPCOMING

### Mobile Security
- [ ] Secure storage (Keychain/Keystore)
- [ ] Biometric app lock
- [ ] Hide sensitive UI in app switcher
- [ ] Root/jailbreak detection
- [ ] Certificate pinning
- [ ] No sensitive logs

### Backend Security
- [ ] JWT middleware for all protected routes
- [ ] Row-level authorization
- [ ] Rate limiting (auth endpoints)
- [ ] PII log scrubbing
- [ ] Request ID tracing
- [ ] CORS configuration
- [ ] Input validation

### Data Retention
- [ ] Automated cleanup job
- [ ] Delete raw statements after 90 days
- [ ] Audit log rotation (365 days)

---

## Phase 5: Notifications & Reminders 🔄 UPCOMING

### Push Notifications
- [ ] FCM integration
- [ ] Reminder scheduling
- [ ] Notification types:
  - [ ] Due in 3 days
  - [ ] Due tomorrow
  - [ ] Due today
  - [ ] Overdue

### In-App Notifications
- [ ] Notification list screen
- [ ] Badge counts
- [ ] Mark as read

---

## Phase 6: Testing & CI/CD 🔄 UPCOMING

### Testing
- [ ] Backend unit tests (pytest)
- [ ] API integration tests
- [ ] Flutter widget tests
- [ ] Flutter integration tests
- [ ] Security testing

### CI/CD
- [ ] GitHub Actions workflow
- [ ] Linting (black, flake8, mypy)
- [ ] Automated testing
- [ ] Build artifacts

---

## Phase 7: Production Prep 🔄 UPCOMING

### Documentation
- [ ] API documentation (OpenAPI)
- [ ] Security documentation
- [ ] Deployment guide
- [ ] User guide

### Deployment
- [ ] Production Docker Compose
- [ ] Environment-specific configs
- [ ] SSL/TLS setup
- [ ] Monitoring (Prometheus/Grafana)
- [ ] Log aggregation

---

## Current Status Summary

| Phase | Status | Progress |
|-------|--------|----------|
| Phase 1: Foundation | ✅ Complete | 100% |
| Phase 2: Parsing Engine | 🔄 In Progress | 0% |
| Phase 3: Mobile UI | ⏳ Pending | 0% |
| Phase 4: Security | ⏳ Pending | 0% |
| Phase 5: Notifications | ⏳ Pending | 0% |
| Phase 6: Testing & CI/CD | ⏳ Pending | 0% |
| Phase 7: Production | ⏳ Pending | 0% |

**Overall Progress:** ~15%
**Estimated MVP Completion:** 4-5 autonomous sessions

---

## Next Build Priority

1. **Celery Worker** — PDF/image parsing pipeline
2. **Bank Parsers** — CTBC, Cathay, Taishin
3. **Mobile Screens** — Login, Dashboard, Cards
4. **Security Layer** — JWT middleware, secure storage

---

*Autonomous development active — next session in ~25 minutes*
