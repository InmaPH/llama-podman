#!/usr/bin/env sh
set -euo pipefail

# -------------------------
# Required runtime config
# -------------------------
: "${HOST:?HOST not set}"
: "${PORT:?PORT not set}"
: "${LLAMA_URL:?LLAMA_URL not set}"

# -------------------------
# Logging (startup visibility)
# -------------------------
echo "[gateway] starting gateway service"
echo "[gateway] host=$HOST port=$PORT"
echo "[gateway] llama_url=$LLAMA_URL"

# -------------------------
# Execution
# -------------------------
exec uvicorn app:app \
  --host "$HOST" \
  --port "$PORT" \
  --workers 2