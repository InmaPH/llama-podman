#!/usr/bin/env bash
# ------------------------------------------------------------
# scripts/deploy.sh – install Quadlet files & start the AI stack
# ------------------------------------------------------------
set -euo pipefail

# ---------- Resolve the project root ----------
SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}")"          # …/llama-podman/scripts/deploy.sh
PROJECT_ROOT="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"  # …/llama-podman

# ---------- Important directories ----------
QUADLET_DIR="${PROJECT_ROOT}/quadlet"                     # container definitions
ENV_SRC_DIR="${PROJECT_ROOT}/config"                     # optional .env source dir
USER_QUADLET_DIR="${HOME}/.config/containers/systemd"    # where podman‑quadlet watches
USER_SYSTEMD_DIR="${HOME}/.config/systemd/user"          # where systemd reads .slice/.target
TARGET_UNIT="ai.target"

# ---------- Helper ----------
h() { echo -e "\n[deploy] $*"; }

# --------------------------------------------------
# Verify images exist
# --------------------------------------------------
if ! podman image exists localhost/llama:b8901; then
    echo "[error] Image localhost/llama:b8901 missing – run build.sh first."
    exit 1
fi
if ! podman image exists localhost/gateway:b8901; then
    echo "[error] Image localhost/gateway:b8901 missing – run build.sh first."
    exit 1
fi

# --------------------------------------------------
# Remove old generated Quadlet units
# --------------------------------------------------
h "Removing cached/generated Quadlet units"
rm -f "${USER_SYSTEMD_DIR}/llama.service" \
      "${USER_SYSTEMD_DIR}/gateway.service" \
      "${USER_SYSTEMD_DIR}/ai.target" \
      "${USER_SYSTEMD_DIR}/ai.slice" 2>/dev/null || true

# --------------------------------------------------
# Install Quadlet container definitions (user‑wide)
# --------------------------------------------------
h "Copying Quadlet files to ${USER_QUADLET_DIR}"
mkdir -p "${USER_QUADLET_DIR}"
cp "${QUADLET_DIR}/llama.container"   "${USER_QUADLET_DIR}/"
cp "${QUADLET_DIR}/gateway.container" "${USER_QUADLET_DIR}/"
cp "${QUADLET_DIR}/ai.pod"            "${USER_QUADLET_DIR}/"
# --------------------------------------------------
# Install slice & target (user‑wide systemd)
# --------------------------------------------------
mkdir -p "${USER_SYSTEMD_DIR}"

if [[ -f "${PROJECT_ROOT}/systemd/ai.slice" ]]; then
    h "Installing ai.slice"
    cp "${PROJECT_ROOT}/systemd/ai.slice" "${USER_SYSTEMD_DIR}/"
fi

if [[ -f "${PROJECT_ROOT}/systemd/ai.target" ]]; then
    h "Installing ai.target"
    cp "${PROJECT_ROOT}/systemd/ai.target" "${USER_SYSTEMD_DIR}/"
else
    h "Creating minimal ${TARGET_UNIT}"
    cat > "${USER_SYSTEMD_DIR}/${TARGET_UNIT}" <<'EOF'
[Unit]
Description=AI stack – Llama + Gateway
Wants=llama.service gateway.service
After=network-online.target

[Install]
WantedBy=default.target
EOF
fi

# --------------------------------------------------
# Copy the environment files into $HOME/.config
# --------------------------------------------------
h "Copying llama.env and gateway.env into ${HOME}/.config"

ENV_DEST="${HOME}/.config"
mkdir -p "${ENV_DEST}"

if [[ -f "${ENV_SRC_DIR}/llama.env" && -f "${ENV_SRC_DIR}/gateway.env" ]]; then
    cp "${ENV_SRC_DIR}/llama.env"   "${ENV_DEST}/llama.env"
    cp "${ENV_SRC_DIR}/gateway.env" "${ENV_DEST}/gateway.env"
else
    echo "[warning] Missing config/llama.env or config/gateway.env"
    echo "[warning] Containers will start with defaults."
fi

# --------------------------------------------------
# Clean stop 
# --------------------------------------------------
h "Stopping AI stack"
systemctl --user stop "${TARGET_UNIT}" 2>/dev/null || true
systemctl --user stop llama.service gateway.service ai-pod.service 2>/dev/null || true

# --------------------------------------------------
# Reset systemd failure state (prevents ghost errors)
# --------------------------------------------------
h "Resetting failed state"
systemctl --user reset-failed llama.service gateway.service 2>/dev/null || true

# --------------------------------------------------
# Force Quadlet regeneration 
# --------------------------------------------------
h "Re-executing systemd manager (Quadlet refresh)"
systemctl --user daemon-reexec

# --------------------------------------------------
# Reload units after reexec
# --------------------------------------------------
h "Reloading systemd daemon"
systemctl --user daemon-reload

# --------------------------------------------------
# Start stack cleanly
# --------------------------------------------------
h "Starting AI stack"
systemctl --user start "${TARGET_UNIT}"

# --------------------------------------------------
# Show status & tail logs
# --------------------------------------------------
h "Service status"
systemctl --user status "${TARGET_UNIT}" llama.service gateway.service --no-pager

h "Tail recent logs (Ctrl‑C to stop)…"
journalctl --user -u llama.service -u gateway.service -n 30 -f || true

h "✔ Deployment finished"
