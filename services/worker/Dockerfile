# Celery Worker for CLIO

FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    tesseract-ocr \
    tesseract-ocr-chi-tra \
    tesseract-ocr-chi-sim \
    tesseract-ocr-eng \
    libtesseract-dev \
    libleptonica-dev \
    poppler-utils \
    libmagic1 \
    libmagic-dev \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Fix permissions
RUN chmod -R 755 /app

# Environment
ENV PYTHONPATH=/app
ENV PYTHONUNBUFFERED=1

# Install celery explicitly
RUN pip install celery[redis]>=5.3.0

# Default command (can be overridden in docker-compose)
CMD ["celery", "-A", "app.worker", "worker", "--loglevel=info", "--concurrency=2"]
