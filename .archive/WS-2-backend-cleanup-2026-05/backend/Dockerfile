# Base Image
FROM python:3.10-slim as builder

# Set Environment Variables
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# Install System Dependencies (for building python packages if needed)
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Working Directory
WORKDIR /app

# Install Dependencies
COPY requirements.txt .
RUN pip wheel --no-cache-dir --no-deps --wheel-dir /app/wheels -r requirements.txt

# Final Stage
FROM python:3.10-slim

# Create a non-root user
RUN addgroup --system app && adduser --system --group app

# Install Runtime Dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# Copy Wheels from Builder
COPY --from=builder /app/wheels /wheels
COPY --from=builder /app/requirements.txt .

# Install Packages
RUN pip install --no-cache /wheels/*

# Copy Application Code
WORKDIR /app
COPY . .

# Change Ownership
RUN chown -R app:app /app

# Switch to non-root user
USER app

# Expose Port
EXPOSE 8000

# Start Command
# Pointing to the new structured app
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
