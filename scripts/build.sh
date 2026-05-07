#!/usr/bin/env bash
# ------------------------------------------------------------
# scripts/build.sh – build the Llama & Gateway images (rootless)
# ------------------------------------------------------------
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TAG="b8901"
LLAMA_IMG="localhost/llama:${TAG}"
GATEWAY_IMG="localhost/gateway:${TAG}"

h() { echo -e "\n[build] $*"; }

# --------------------------------------------------
# 1️⃣ Remove previous tags (layers stay cached)
# --------------------------------------------------
h "Removing previous tags (if any)…"
podman rmi -f "${LLAMA_IMG}" "${GATEWAY_IMG}" || true

# --------------------------------------------------
# 2️⃣ Build images – reuse local layers, never pull from the internet
# --------------------------------------------------
h "Building llama image…"
podman build --pull=false \
    -t "${LLAMA_IMG}" \
    -f "${PROJECT_ROOT}/containers/llama.Containerfile" \
    "${PROJECT_ROOT}"

h "Building gateway image…"
podman build --pull=false \
    -t "${GATEWAY_IMG}" \
    -f "${PROJECT_ROOT}/containers/gateway.Containerfile" \
    "${PROJECT_ROOT}"

# --------------------------------------------------
# 3️⃣ Prune dangling images to save space
# --------------------------------------------------
h "Pruning dangling images…"
podman image prune -f || true

h "✅ Image build completed."
