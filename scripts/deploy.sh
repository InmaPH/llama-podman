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
# 0️⃣ Verify images exist
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
# 1️⃣ Install Quadlet container definitions (user‑wide)
# --------------------------------------------------
h "Copying Quadlet files to ${USER_QUADLET_DIR}"
mkdir -p "${USER_QUADLET_DIR}"
cp "${QUADLET_DIR}/llama.container"   "${USER_QUADLET_DIR}/"
cp "${QUADLET_DIR}/gateway.container" "${USER_QUADLET_DIR}/"

# --------------------------------------------------
# 2️⃣ Install slice & target (user‑wide systemd)
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
# 3️⃣ Copy the environment files into $HOME/.config
# --------------------------------------------------
h "Copying llama.env and gateway.env into ${HOME}/.config"
ENV_DEST="${HOME}/.config"
mkdir -p "${ENV_DEST}"

if [[ -f "${PROJECT_ROOT}/llama.env" && -f "${PROJECT_ROOT}/gateway.env" ]]; then
    cp "${PROJECT_ROOT}/llama.env"   "${ENV_DEST}/llama.env"
    cp "${PROJECT_ROOT}/gateway.env" "${ENV_DEST}/gateway.env"
else
    if [[ -f "${PROJECT_ROOT}/.env" ]]; then
        h "Single .env detected – extracting needed variables"
        grep -E '^(MODEL|THREADS|CONTEXT_SIZE|GPU_LAYERS|HOST|PORT)=' \
            "${PROJECT_ROOT}/.env" > "${ENV_DEST}/llama.env"

        {
            echo "HOST=0.0.0.0"
            echo "PORT=8000"
            grep -E '^LLAMA_URL=' "${PROJECT_ROOT}/.env"
        } > "${ENV_DEST}/gateway.env"
    else
        echo "[warning] No env files found – containers will start with defaults."
    fi
fi

# --------------------------------------------------
# 4️⃣ Reload the user systemd daemon
# --------------------------------------------------
h "Reloading user systemd daemon"
systemctl --user daemon-reload

# --------------------------------------------------
# 5️⃣ Enable & start the target
# --------------------------------------------------
h "Enabling and starting ${TARGET_UNIT}"
systemctl --user enable --now "${TARGET_UNIT}"

# --------------------------------------------------
# 6️⃣ Show status & tail logs
# --------------------------------------------------
h "Service status"
systemctl --user status "${TARGET_UNIT}" llama.service gateway.service --no-pager

h "Tail recent logs (Ctrl‑C to stop)…"
journalctl --user -u llama.service -u gateway.service -n 30 -f || true

h "✅ Deployment finished."
