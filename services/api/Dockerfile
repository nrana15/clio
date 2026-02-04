FROM python:3.12-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    libpq-dev \
    libmagic1 \
    tesseract-ocr \
    tesseract-ocr-chi-tra \
    tesseract-ocr-chi-sim \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies as root
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Create alembic directories if they don't exist
RUN mkdir -p alembic/versions

# Fix permissions
RUN chmod -R 755 /app

# Run as root (simpler for Windows)
USER root

EXPOSE 8000

# Check if alembic.ini exists, if not skip migrations
CMD ["sh", "-c", "if [ -f alembic.ini ]; then python -m alembic upgrade head; fi && python -m uvicorn app.main:app --host 0.0.0.0 --port 8000"]
