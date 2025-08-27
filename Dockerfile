FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY zeroa_messaging_server.py .

# Create necessary directories
RUN mkdir -p /opt/zeroa-messaging/logs

# Expose port
EXPOSE 8000

# Set environment variables
ENV PYTHONPATH=/app
ENV TLS_API_URL=https://telestai.cryptoscope.io/api

# Run the application
CMD ["python", "zeroa_messaging_server.py"] 