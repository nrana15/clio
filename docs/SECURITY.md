# CLIO Security Documentation

This document outlines the security measures, best practices, and considerations for the CLIO application.

## Table of Contents

1. [Security Principles](#security-principles)
2. [Authentication & Authorization](#authentication--authorization)
3. [Data Protection](#data-protection)
4. [API Security](#api-security)
5. [Mobile Security](#mobile-security)
6. [Infrastructure Security](#infrastructure-security)
7. [Compliance](#compliance)
8. [Incident Response](#incident-response)

---

## Security Principles

CLIO is built on the following security principles:

1. **Defense in Depth**: Multiple layers of security controls
2. **Least Privilege**: Minimal access rights for each component
3. **Data Minimization**: Only store necessary data
4. **Privacy by Design**: Privacy considerations from the ground up
5. **Transparency**: Clear communication about data handling

---

## Authentication & Authorization

### OTP-Based Authentication

- **6-digit OTP** sent via SMS or email
- **5-minute expiration** for OTP codes
- **Rate limiting** on OTP requests (3 per minute)
- **Hashed storage** of OTP codes (SHA-256)
- **Attempt tracking** to prevent brute force

### JWT Token Management

```
Access Token:
- Expiration: 30 minutes
- Contains: user_id, exp, type="access"
- Algorithm: HS256

Refresh Token:
- Expiration: 7 days
- Contains: user_id, exp, type="refresh", jti
- Unique ID (jti) for revocation support
```

### Token Security

- Tokens are signed with a 32+ character secret key
- Short-lived access tokens minimize impact of theft
- Refresh tokens can be revoked on logout
- Tokens are transmitted over HTTPS only
- Mobile app stores tokens in encrypted storage (Keychain/Keystore)

### Authorization Model

| Role | Permissions |
|------|-------------|
| User | CRUD own cards, bills, settings |
| System | Background processing, notifications |
| Admin | User management, system monitoring (future) |

---

## Data Protection

### Sensitive Data Handling

**What We Store:**
- ✓ Card last 4 digits only
- ✓ Bank name/issuer
- ✓ Statement dates and amounts
- ✓ User phone/email
- ✓ Hashed OTP codes

**What We DON'T Store:**
- ✗ Full card numbers (PAN)
- ✗ CVV/CVC codes
- ✗ Card expiration dates
- ✓ Card magnetic stripe data
- ✓ Statement transaction details (future feature)

### Encryption

| Data Type | At Rest | In Transit |
|-----------|---------|------------|
| User data | Database encryption | TLS 1.3 |
| Files | Server-side encryption (MinIO) | TLS 1.3 |
| Tokens | Encrypted device storage | TLS 1.3 |
| OTP codes | Hashed (SHA-256) | TLS 1.3 |

### Database Security

- PostgreSQL with SSL/TLS connections
- Connection pooling with timeout limits
- Prepared statements to prevent SQL injection
- Row-level security for multi-tenancy (future)

---

## API Security

### Rate Limiting

Implemented using token bucket algorithm:

```python
Anonymous:    20 requests / 60 seconds, burst: 5
Authenticated: 100 requests / 60 seconds, burst: 10
Premium:      1000 requests / 60 seconds, burst: 50
```

Headers returned:
```
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1704067200
Retry-After: 45  (when limited)
```

### Input Validation

- Pydantic schemas validate all inputs
- SQL injection prevention via SQLAlchemy ORM
- XSS protection via output encoding
- File type validation for uploads
- File size limits (10MB max)

### Request Tracing

Every request receives:
- Unique `X-Request-ID` header
- Response time tracking
- Structured logging with correlation IDs

### CORS Configuration

```python
Allow-Origins: ["https://clio.app", "https://api.clio.app"]
Allow-Methods: ["GET", "POST", "PUT", "PATCH", "DELETE"]
Allow-Credentials: true
Max-Age: 600
```

---

## Mobile Security

### Biometric Authentication

**Supported Methods:**
- iOS: Face ID, Touch ID
- Android: Fingerprint, Face Unlock

**Implementation:**
```dart
// Uses local_auth package
// Fallback to PIN/Pattern enabled
// Biometric data never leaves device
```

### Root/Jailbreak Detection

Using `jailbreak_root_detection` package:

| Check | iOS | Android |
|-------|-----|---------|
| Jailbreak/Root | ✓ | ✓ |
| Emulator | ✓ | ✓ |
| Debug mode | ✓ | ✓ |
| Mock location | N/A | ✓ |

**Behavior:**
- Warning shown on compromised devices
- User can continue at their own risk
- Enhanced logging for support

### Secure Storage

| Platform | Storage | Encryption |
|----------|---------|------------|
| iOS | Keychain | AES-256-GCM |
| Android | EncryptedSharedPreferences | AES-256-GCM |

**Stored Data:**
- Access token
- Refresh token
- User ID
- Biometric preference
- App settings

### App Switcher Protection

```dart
// Privacy overlay when app enters background
SecureAppLifecycleObserver(
  secureOnBackground: true,
  child: MyApp(),
)
```

Shows lock icon overlay in app switcher to hide sensitive content.

### Certificate Pinning

Future implementation:
```dart
// dio_http_certificate_pinning package
// Pin to specific certificate/public key
// Prevents man-in-the-middle attacks
```

---

## Infrastructure Security

### Network Architecture

```
Internet → Load Balancer (HTTPS) → API Servers → Database
                                    ↓
                              Object Storage (MinIO)
                                    ↓
                              Queue/Cache (Redis)
```

### Container Security

- Non-root user in containers
- Read-only filesystem where possible
- Security scanning with Trivy
- Minimal base images (Distroless/Alpine)

### Secrets Management

- Environment variables for configuration
- Kubernetes Secrets for credentials (production)
- Never commit secrets to repository
- Regular secret rotation

### Monitoring & Alerting

| Metric | Alert Threshold |
|--------|-----------------|
| Failed auth attempts | > 10/minute |
| Error rate | > 5% |
| Response time | > 2s average |
| Rate limit hits | > 100/hour |

---

## Compliance

### Data Retention

| Data Type | Retention Period |
|-----------|-----------------|
| Source artifacts | 90 days |
| Audit logs | 365 days |
| OTP attempts | 30 days |
| User accounts | Until deletion |

### User Rights

Users can:
- ✓ Export their data
- ✓ Delete their account
- ✓ View connected devices
- ✓ Revoke sessions

### GDPR Considerations

- Explicit consent for data processing
- Right to erasure implemented
- Data portability (JSON export)
- Privacy policy required

---

## Incident Response

### Security Incident Levels

| Level | Description | Response Time |
|-------|-------------|---------------|
| P0 | Data breach, RCE | 1 hour |
| P1 | Auth bypass, DoS | 4 hours |
| P2 | XSS, CSRF | 24 hours |
| P3 | Info disclosure | 72 hours |

### Response Process

1. **Detect**: Monitoring alerts, user reports
2. **Assess**: Impact analysis, scope determination
3. **Contain**: Stop the attack, limit damage
4. **Eradicate**: Remove threat, patch vulnerability
5. **Recover**: Restore services, verify integrity
6. **Learn**: Post-incident review, process improvement

### Security Contacts

- Security Team: security@clio.app
- Emergency: +886-XXX-XXXX

---

## Security Checklist

### For Developers

- [ ] Run security linter (bandit)
- [ ] No secrets in code
- [ ] Input validation on all endpoints
- [ ] Rate limiting on sensitive operations
- [ ] Tests for security features
- [ ] Dependency vulnerability check

### For DevOps

- [ ] HTTPS only (TLS 1.3)
- [ ] Security headers configured
- [ ] Database backups encrypted
- [ ] Log aggregation configured
- [ ] Network segmentation verified
- [ ] Disaster recovery tested

### For Mobile

- [ ] Biometric auth tested
- [ ] Jailbreak detection enabled
- [ ] Secure storage verified
- [ ] App switcher protection active
- [ ] Certificate pinning configured
- [ ] Obfuscation applied (production)

---

## Security Resources

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [FastAPI Security](https://fastapi.tiangolo.com/tutorial/security/)
- [Flutter Security](https://flutter.dev/docs/development/data-and-backend/networking)
- [PostgreSQL Security](https://www.postgresql.org/docs/current/security.html)

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2024-02 | Initial security documentation |

---

*Last Updated: February 4, 2024*
*Document Owner: CLIO Security Team*
