# Celery Worker for CLIO
# For local development only; auto-reloads on changes

FROM python:3.11-slim

WORKDIR /app

# Install system dependencies for Tesseract OCR and PDF processing
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

# Use python module syntax
ENV PYTHONPATH=/app
ENV PYTHONUNBUFFERED=1

# Run celery using python module
CMD ["python", "-m", "celery", "-A", "app.worker", "worker", "--loglevel=info", "--concurrency=2"]
