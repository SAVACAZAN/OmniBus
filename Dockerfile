# Dockerfile for OmniBus API Gateway
# Production-grade containerization for FastAPI microservice

FROM python:3.11-slim

LABEL maintainer="OmniBus Team <learn@omnibus.ai>"
LABEL description="OmniBus API Gateway - Real-time trading engine REST/WebSocket API"

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements
COPY services/requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY services/ /app/

# Expose API port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Run API gateway
CMD ["python3", "omnibus_api_gateway.py"]
