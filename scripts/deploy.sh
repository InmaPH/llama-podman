#!/usr/bin/env bash
# ------------------------------------------------------------
# scripts/deploy.sh – install Quadlet files & start the AI stack
# Pod-based architecture (ai-pod.service)
# ------------------------------------------------------------
set -euo pipefail

# ------------------------------------------------------------
# Project root + standardized paths
# ------------------------------------------------------------
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

QUADLET_SRC="${PROJECT_ROOT}/quadlet"
SYSTEMD_SRC="${PROJECT_ROOT}/systemd"
ENV_SRC="${PROJECT_ROOT}/config"

QUADLET_DST="${HOME}/.config/containers/systemd"
SYSTEMD_DST="${HOME}/.config/systemd/user"
ENV_DST="${HOME}/.config/containers/env"

TARGET="ai.target"

h() { echo -e "\n[deploy] $*"; }

# --------------------------------------------------
# Verify images exist
# --------------------------------------------------
for img in localhost/llama:b8901 localhost/gateway:b8901; do
    if ! podman image exists "$img"; then
        echo "[error] Missing image: $img (run build.sh first)"
        exit 1
    fi
done

# --------------------------------------------------
# Install Quadlet definitions
# --------------------------------------------------
h "Copying Quadlet files"

mkdir -p "${QUADLET_DST}"

cp "${QUADLET_SRC}/llama.container"   "${QUADLET_DST}/"
cp "${QUADLET_SRC}/gateway.container" "${QUADLET_DST}/"
cp "${QUADLET_SRC}/ai.pod"            "${QUADLET_DST}/"

# --------------------------------------------------
# Install systemd units (slice + target)
# --------------------------------------------------
h "Installing systemd units"

mkdir -p "${SYSTEMD_DST}"

cp "${SYSTEMD_SRC}/ai.slice"  "${SYSTEMD_DST}/"
cp "${SYSTEMD_SRC}/ai.target" "${SYSTEMD_DST}/"

# --------------------------------------------------
# Install environment files (Quadlet runtime config)
# --------------------------------------------------
h "Installing environment files"

mkdir -p "${ENV_DST}"

if [[ -f "${ENV_SRC}/llama.env" ]]; then
    cp "${ENV_SRC}/llama.env" "${ENV_DST}/llama.env"
else
    echo "[warning] Missing llama.env"
fi

if [[ -f "${ENV_SRC}/gateway.env" ]]; then
    cp "${ENV_SRC}/gateway.env" "${ENV_DST}/gateway.env"
else
    echo "[warning] Missing gateway.env"
fi

# --------------------------------------------------
# Clean stop (runtime only)
# --------------------------------------------------
h "Stopping AI stack"

systemctl --user stop "${TARGET}" 2>/dev/null || true
systemctl --user stop ai-pod.service 2>/dev/null || true

# --------------------------------------------------
# Reset runtime failure state
# --------------------------------------------------
h "Resetting failed state"

systemctl --user reset-failed ai-pod.service 2>/dev/null || true

# --------------------------------------------------
# Reload systemd (Quadlet refresh)
# --------------------------------------------------
h "Reloading systemd daemon"

systemctl --user daemon-reload

# --------------------------------------------------
# Start stack
# --------------------------------------------------
h "Starting AI stack"

systemctl --user start "${TARGET}"

# --------------------------------------------------
# Status
# --------------------------------------------------
h "Service status"

systemctl --user status "${TARGET}" ai-pod.service --no-pager || true

# --------------------------------------------------
# Logs
# --------------------------------------------------
h "Recent logs"

journalctl --user -u ai-pod.service -n 50 --no-pager || true

h "✔ Deployment finished"