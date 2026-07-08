#!/usr/bin/env bash
# ------------------------------------------------------------
# scripts/build.sh – build the Llama & Gateway images (rootless)
# ------------------------------------------------------------
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TAG="b8901"
LLAMA_IMG="localhost/llama:${TAG}"
GATEWAY_IMG="localhost/gateway:${TAG}"

h() { echo -e "\n[build] $*"; }

# --------------------------------------------------
# Remove previous tags (layers stay cached)
# --------------------------------------------------
h "Removing previous images (if they exist)…"

for img in "${LLAMA_IMG}" "${GATEWAY_IMG}"; do
    podman image exists "$img" && podman rmi "$img" || true
done

# --------------------------------------------------
# Build images – reuse local layers, never pull from the internet
# --------------------------------------------------
h "Building llama image…"
podman build --pull=missing \
    -t "${LLAMA_IMG}" \
    -f "${PROJECT_ROOT}/containers/llama.Containerfile" \
    "${PROJECT_ROOT}"

h "Building gateway image…"
podman build --pull=missing \
    -t "${GATEWAY_IMG}" \
    -f "${PROJECT_ROOT}/containers/gateway.Containerfile" \
    "${PROJECT_ROOT}"

# --------------------------------------------------
# Prune dangling images to save space and check
# --------------------------------------------------
h "Pruning dangling images…"
podman image prune -f || true

h "Verifying build outputs…"

podman image exists "${LLAMA_IMG}" || {
    echo "[error] llama image not built"
    exit 1
}

podman image exists "${GATEWAY_IMG}" || {
    echo "[error] gateway image not built"
    exit 1
}

h "✔ Image build completed."
