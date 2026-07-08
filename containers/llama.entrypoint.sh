#!/usr/bin/env sh
set -euo pipefail

# -------------------------
# Required config validation
# -------------------------

missing=0

require_var() {
  var_name="$1"
  value="${!var_name:-}"

  if [ -z "$value" ]; then
    echo "[llama] ERROR: missing required env var: $var_name"
    missing=1
  fi
}

require_var MODEL
require_var THREADS
require_var GPU_LAYERS
require_var CONTEXT_SIZE
require_var HOST
require_var PORT

if [ "$missing" -ne 0 ]; then
  echo "[llama] FATAL: missing required configuration, aborting startup"
  exit 1
fi

# -------------------------
# GPU runtime environment
# -------------------------

: "${GGML_VULKAN_VISIBLE_DEVICES:=0}"
export GGML_VULKAN_VISIBLE_DEVICES

: "${VK_LOADER_DEBUG:=warn}"
export VK_LOADER_DEBUG

# -------------------------
# Safety caps (hardware + risk-averse)
# -------------------------

if [ "$GPU_LAYERS" -gt 80 ]; then
  echo "[llama] WARNING: GPU_LAYERS capped to 80"
  GPU_LAYERS=80
fi

if [ "$CONTEXT_SIZE" -gt 8192 ]; then
  echo "[llama] WARNING: CONTEXT_SIZE capped to 8192"
  CONTEXT_SIZE=8192
fi

if [ "$THREADS" -gt 10 ]; then
  echo "[llama] WARNING: THREADS capped to 10"
  THREADS=10
fi

if [ "$THREADS" -lt 4 ]; then
  echo "[llama] WARNING: THREADS raised to 4 (minimum safe baseline)"
  THREADS=4
fi

: "${OMP_NUM_THREADS:=$THREADS}"
export OMP_NUM_THREADS

# -------------------------
# Startup validation
# -------------------------

echo "[llama] validating runtime..."

if command -v vulkaninfo >/dev/null 2>&1; then
  if ! vulkaninfo --summary >/dev/null 2>&1; then
    echo "[llama] ERROR: Vulkan is not functional"
    exit 1
  fi
else
  echo "[llama] WARNING: vulkaninfo not installed"
fi

LLAMA_BINARY="/opt/llama/bin/llama-server"

# Binary check
if [ ! -x "$LLAMA_BINARY" ]; then
  echo "[llama] ERROR: llama-server not found or not executable at $LLAMA_BINARY"
  exit 1
fi

# GPU check
if ! ls /dev/dri/renderD* >/dev/null 2>&1; then
  echo "[llama] ERROR: no GPU render device found"
  exit 1
fi

# Model check
if [ ! -f "$MODEL" ]; then
  echo "[llama] ERROR: model not found at $MODEL"
  exit 1
fi

MODEL_DIR="$(dirname "$MODEL")"

set -- "$MODEL_DIR"/*.gguf
[ -e "$1" ] || {
  echo "[llama] ERROR: no model shards found in $MODEL_DIR"
  exit 1
}

for shard in "$MODEL_DIR"/*.gguf; do
  [ -f "$shard" ] || {
    echo "[llama] ERROR: missing model shard $shard"
    exit 1
  }
done

# -------------------------
# Logging
# -------------------------

echo "[llama] booting container"
echo "[llama] host=$HOST port=$PORT"
echo "[llama] model=$MODEL"
echo "[llama] threads=$THREADS"
echo "[llama] omp_threads=$OMP_NUM_THREADS"
echo "[llama] context=$CONTEXT_SIZE"
echo "[llama] gpu_layers=$GPU_LAYERS"
echo "[llama] vulkan_devices=$GGML_VULKAN_VISIBLE_DEVICES"
echo "[llama] vulkan_loader=auto"

# -------------------------
# Execution
# -------------------------

exec "$LLAMA_BINARY" \
  --host "$HOST" \
  --port "$PORT" \
  -m "$MODEL" \
  -c "$CONTEXT_SIZE" \
  -t "$THREADS" \
  --n-gpu-layers "$GPU_LAYERS"