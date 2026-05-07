FROM python:3.11-slim

# -------------------------
# System dependencies
# -------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl \
    && rm -rf /var/lib/apt/lists/*

# -------------------------
# Python dependencies
# -------------------------
COPY requirements.txt /tmp/requirements.txt

RUN pip install --no-cache-dir -r /tmp/requirements.txt && \
    rm -rf /root/.cache

# -------------------------
# Security: non-root user
# -------------------------
RUN useradd -m -u 1000 gateway

WORKDIR /app

COPY gateway/app.py /app/app.py
COPY containers/gateway.entrypoint.sh /entrypoint.sh

RUN chown -R gateway:gateway /app && \
    chmod +x /entrypoint.sh

USER gateway

# -------------------------
# Runtime config
# -------------------------
ENV PYTHONUNBUFFERED=1

# -------------------------
# Execution
# -------------------------
CMD ["/entrypoint.sh"]