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

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Create alembic directories
RUN mkdir -p alembic/versions

# Fix permissions
RUN chmod -R 755 /app

EXPOSE 8000

# Run migrations then start server
# Use alembic directly, not python -m alembic
CMD sh -c "alembic upgrade head 2>/dev/null || echo 'No migrations to run' && uvicorn app.main:app --host 0.0.0.0 --port 8000"
