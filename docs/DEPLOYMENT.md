# CLIO Deployment Guide

This guide covers deploying CLIO to production environments.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Environment Configuration](#environment-configuration)
3. [SSL/TLS Setup](#ssltls-setup)
4. [Docker Deployment](#docker-deployment)
5. [Monitoring](#monitoring)
6. [Backup & Recovery](#backup--recovery)

---

## Prerequisites

### Server Requirements

- **OS**: Ubuntu 22.04 LTS or similar Linux distribution
- **CPU**: 2+ cores
- **RAM**: 4GB minimum, 8GB recommended
- **Storage**: 50GB SSD minimum
- **Network**: Static IP, ports 80/443 open

### Required Software

- Docker 24.0+
- Docker Compose 2.20+
- Nginx or Traefik (for SSL termination)
- Certbot (for Let's Encrypt certificates)

---

## Environment Configuration

### Production Environment Variables

Create a `.env.production` file:

```bash
# Environment
ENVIRONMENT=production
DEBUG=false

# Database (Use managed PostgreSQL for production)
DATABASE_URL=postgresql+asyncpg://user:password@db.clio.internal:5432/clio

# Redis (Use managed Redis or Elasticache)
REDIS_URL=redis://redis.clio.internal:6379/0

# Security (Use strong secrets!)
JWT_SECRET=<generate-with-openssl-rand-base64-32>
ACCESS_TOKEN_EXPIRE_MINUTES=30
REFRESH_TOKEN_EXPIRE_DAYS=7

# MinIO / S3 (Use AWS S3 or Google Cloud Storage)
MINIO_ENDPOINT=s3.amazonaws.com
MINIO_ACCESS_KEY=AKIA...
MINIO_SECRET_KEY=...
MINIO_BUCKET=clio-production-statements
MINIO_USE_SSL=true

# FCM Push Notifications
FCM_SERVER_KEY=<your-fcm-server-key>

# Email Webhook
EMAIL_WEBHOOK_SECRET=<generate-random-secret>

# Data Retention
STATEMENT_RETENTION_DAYS=90
AUDIT_LOG_RETENTION_DAYS=365

# File Upload
MAX_UPLOAD_SIZE_MB=10
ALLOWED_UPLOAD_TYPES=application/pdf,image/jpeg,image/png

# Prometheus Metrics
ENABLE_METRICS=true
METRICS_PORT=9090
```

### Generating Secrets

```bash
# Generate JWT secret
openssl rand -base64 32

# Generate webhook secret
openssl rand -hex 32
```

---

## SSL/TLS Setup

### Option 1: Let's Encrypt with Certbot

```bash
# Install Certbot
sudo apt update
sudo apt install certbot python3-certbot-nginx

# Obtain certificates
sudo certbot certonly --standalone -d api.clio.app -d clio.app

# Auto-renewal (usually set up automatically)
sudo certbot renew --dry-run
```

### Option 2: Using Traefik (Recommended for Docker)

Traefik automatically manages Let's Encrypt certificates:

```yaml
# docker-compose.prod.yml
services:
  traefik:
    image: traefik:v3.0
    command:
      - "--api.insecure=true"
      - "--providers.docker=true"
      - "--entrypoints.web.address=:80"
      - "--entrypoints.websecure.address=:443"
      - "--certificatesresolvers.letsencrypt.acme.tlschallenge=true"
      - "--certificatesresolvers.letsencrypt.acme.email=admin@clio.app"
      - "--certificatesresolvers.letsencrypt.acme.storage=/letsencrypt/acme.json"
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./letsencrypt:/letsencrypt
```

### SSL Configuration Best Practices

1. **TLS Version**: Minimum TLS 1.2, prefer TLS 1.3
2. **Cipher Suites**: Use strong ciphers only
3. **HSTS**: Enable HTTP Strict Transport Security
4. **Certificate**: Use valid, non-expired certificates

### Nginx SSL Configuration Example

```nginx
server {
    listen 443 ssl http2;
    server_name api.clio.app;

    ssl_certificate /etc/letsencrypt/live/api.clio.app/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api.clio.app/privkey.pem;
    ssl_trusted_certificate /etc/letsencrypt/live/api.clio.app/chain.pem;

    # SSL Configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256';
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 1d;
    ssl_session_tickets off;

    # HSTS
    add_header Strict-Transport-Security "max-age=63072000" always;

    location / {
        proxy_pass http://api:8000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}

# Redirect HTTP to HTTPS
server {
    listen 80;
    server_name api.clio.app;
    return 301 https://$server_name$request_uri;
}
```

---

## Docker Deployment

### Production Docker Compose

```yaml
# docker-compose.prod.yml
version: '3.8'

services:
  api:
    image: ghcr.io/yourusername/clio:main-api
    environment:
      - ENVIRONMENT=production
    env_file:
      - .env.production
    deploy:
      replicas: 2
      resources:
        limits:
          cpus: '1.0'
          memory: 1G
        reservations:
          cpus: '0.5'
          memory: 512M
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/healthz"]
      interval: 30s
      timeout: 10s
      retries: 3
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.api.rule=Host(`api.clio.app`)"
      - "traefik.http.routers.api.tls.certresolver=letsencrypt"

  worker:
    image: ghcr.io/yourusername/clio:main-worker
    environment:
      - ENVIRONMENT=production
    env_file:
      - .env.production
    deploy:
      replicas: 2
      resources:
        limits:
          cpus: '1.0'
          memory: 2G
    depends_on:
      - redis

  beat:
    image: ghcr.io/yourusername/clio:main-worker
    command: celery -A app.tasks beat -l info
    environment:
      - ENVIRONMENT=production
    env_file:
      - .env.production
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 512M

  redis:
    image: redis:7-alpine
    volumes:
      - redis_data:/data
    deploy:
      resources:
        limits:
          memory: 512M

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - /etc/letsencrypt:/etc/letsencrypt:ro
    depends_on:
      - api

volumes:
  redis_data:
```

### Deployment Steps

```bash
# 1. Clone repository
git clone https://github.com/yourusername/clio.git
cd clio

# 2. Create environment file
cp .env.example .env.production
nano .env.production  # Edit with your values

# 3. Pull latest images
docker-compose -f docker-compose.prod.yml pull

# 4. Run database migrations
docker-compose -f docker-compose.prod.yml run --rm api alembic upgrade head

# 5. Start services
docker-compose -f docker-compose.prod.yml up -d

# 6. Verify deployment
curl https://api.clio.app/healthz
curl https://api.clio.app/readyz
```

---

## Monitoring

### Prometheus Configuration

Prometheus metrics are available at `/metrics` endpoint.

### Grafana Dashboard

Key metrics to monitor:

1. **Application Metrics**
   - Request rate and latency
   - Error rate (5xx responses)
   - Active connections

2. **Business Metrics**
   - Bills processed per hour
   - OCR confidence scores
   - User signups

3. **Infrastructure Metrics**
   - CPU/Memory usage
   - Database connections
   - Redis memory usage

### Alerting Rules

```yaml
# prometheus-alerts.yml
groups:
  - name: clio
    rules:
      - alert: HighErrorRate
        expr: rate(http_requests_total{status_code=~"5.."}[5m]) > 0.1
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "High error rate detected"

      - alert: DatabaseDown
        expr: up{job="postgres"} == 0
        for: 1m
        labels:
          severity: critical

      - alert: APIDown
        expr: up{job="api"} == 0
        for: 1m
        labels:
          severity: critical
```

---

## Backup & Recovery

### Database Backup

```bash
# Automated daily backup script
#!/bin/bash
BACKUP_DIR=/backups/postgres
DATE=$(date +%Y%m%d_%H%M%S)
docker exec clio_postgres_1 pg_dump -U clio clio | gzip > $BACKUP_DIR/backup_$DATE.sql.gz

# Keep only last 30 days
find $BACKUP_DIR -name "backup_*.sql.gz" -mtime +30 -delete
```

### S3/MinIO Backup

```bash
# Sync to backup bucket
aws s3 sync s3://clio-production-statements s3://clio-backup-statements
```

### Recovery Procedures

1. **Database Recovery**
   ```bash
   # Restore from backup
   gunzip < backup_20240204_120000.sql.gz | docker exec -i clio_postgres_1 psql -U clio clio
   ```

2. **Full System Recovery**
   - Restore database from backup
   - Redeploy containers with `docker-compose up -d`
   - Verify health endpoints
   - Check application logs

---

## Security Checklist

- [ ] Change all default passwords
- [ ] Enable firewall (ufw/cloud provider)
- [ ] Configure fail2ban for SSH
- [ ] Disable root SSH login
- [ ] Set up log aggregation
- [ ] Enable automated security updates
- [ ] Regular vulnerability scans
- [ ] Database encryption at rest
- [ ] Backup encryption

---

## Troubleshooting

### Common Issues

**Database connection errors:**
```bash
# Check database connectivity
docker exec clio_api_1 python -c "import asyncio; from app.db.session import async_engine; asyncio.run(async_engine.connect())"
```

**High memory usage:**
```bash
# Check memory usage
docker stats

# Restart services if needed
docker-compose -f docker-compose.prod.yml restart api worker
```

**SSL certificate issues:**
```bash
# Renew certificates
sudo certbot renew --force-renewal

# Verify certificate
openssl x509 -in /etc/letsencrypt/live/api.clio.app/cert.pem -text -noout
```
