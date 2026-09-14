#!/bin/bash

# ============================================================
# UVM PANEL INSTALLER
# ============================================================

set -Eeuo pipefail

# ============================================================
# COLORS
# ============================================================

RED='\e[1;31m'
GREEN='\e[1;32m'
YELLOW='\e[1;33m'
CYAN='\e[1;36m'
MAGENTA='\e[1;35m'
NC='\e[0m'

# ============================================================
# CONFIGURATION
# ============================================================

INSTALL_DIR="/opt/uvm-panel"
LOG_FILE="/var/log/uvm-panel.log"
SERVICE_NAME="uvm-panel"

# ============================================================
# GITHUB DETAILS
# PUBLIC REPOSITORY - NO TOKEN REQUIRED
# ============================================================

GITHUB_USERNAME="stripathi02123-tech"
GITHUB_REPO_NAME="Uvm-panel"

REPO_URL="https://github.com/${GITHUB_USERNAME}/${GITHUB_REPO_NAME}.git"

# ============================================================
# HELPERS
# ============================================================

line() {
    echo -e "${MAGENTA}============================================================${NC}"
}

info() {
    echo -e "${CYAN}[INFO]${NC} $*"
}

ok() {
    echo -e "${GREEN}[OK]${NC} $*"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

die() {
    error "$*"
    exit 1
}

# ============================================================
# START
# ============================================================

clear

echo -e "${CYAN}"
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                    UVM PANEL INSTALLER                     ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

line

# ============================================================
# ROOT CHECK
# ============================================================

if [[ "${EUID}" -ne 0 ]]; then
    die "Please run this installer as root."
fi

ok "Root access detected."

# ============================================================
# INSTALL DIRECTORY
# ============================================================

mkdir -p "${INSTALL_DIR}"

# ============================================================
# SYSTEM DEPENDENCIES
# ============================================================

line
info "Installing system utilities and LXC/LXD dependencies..."

export DEBIAN_FRONTEND=noninteractive

apt-get update -qq -y >/dev/null 2>&1 || true

apt-get install -y \
    curl \
    wget \
    git \
    python3 \
    python3-pip \
    python3-venv \
    jq \
    lxd \
    lxc \
    >/dev/null 2>&1 || true

ok "System utilities and LXC/LXD dependencies installed."

# ============================================================
# NGINX
# ============================================================

info "Installing NGINX..."

apt-get install -y nginx >/dev/null 2>&1 || true

dpkg --configure -a >/dev/null 2>&1 || true

ok "NGINX installed."

# ============================================================
# NGINX CONFIGURATION
# ============================================================

info "Configuring NGINX..."

mkdir -p /etc/nginx/sites-available
mkdir -p /etc/nginx/sites-enabled

cat > /tmp/nginx_uvm.conf << 'EOF'
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:5000;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        proxy_http_version 1.1;
        proxy_set_header Connection "";

        proxy_read_timeout 86400;
        proxy_send_timeout 86400;
    }

    location ~ ^/terminal/(?<vps_port>[0-9]+)/ {
        proxy_pass http://127.0.0.1:$vps_port;

        proxy_http_version 1.1;

        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;

        proxy_read_timeout 86400;
        proxy_send_timeout 86400;
    }
}
EOF

rm -f /etc/nginx/sites-enabled/default

mv /tmp/nginx_uvm.conf \
   /etc/nginx/sites-available/uvm-panel

ln -sf \
   /etc/nginx/sites-available/uvm-panel \
   /etc/nginx/sites-enabled/uvm-panel

if nginx -t >/dev/null 2>&1; then
    systemctl restart nginx || true
    systemctl enable nginx >/dev/null 2>&1 || true
    ok "NGINX configured successfully."
else
    error "NGINX configuration test failed."
    nginx -t || true
    die "Stopping installation because NGINX configuration is invalid."
fi

# ============================================================
# TTYD
# ============================================================

info "Cleaning previous ttyd installation..."

pkill -x ttyd >/dev/null 2>&1 || true
rm -f /usr/local/bin/ttyd

info "Installing ttyd..."

wget -qO /usr/local/bin/ttyd \
    "https://github.com/tsl0922/ttyd/releases/download/1.7.7/ttyd.x86_64"

if [[ ! -s /usr/local/bin/ttyd ]]; then
    die "Failed to install ttyd."
fi

chmod +x /usr/local/bin/ttyd

if ! /usr/local/bin/ttyd --version >/dev/null 2>&1; then
    warn "ttyd was downloaded but version check failed."
fi

ok "ttyd installed."

# ============================================================
# CLONE UVM PANEL
# ============================================================

line
info "Cloning UVM Panel from GitHub..."

rm -rf "${INSTALL_DIR}"

git clone \
    --depth 1 \
    "${REPO_URL}" \
    "${INSTALL_DIR}"

cd "${INSTALL_DIR}"

ok "Repository cloned successfully."

# ============================================================
# VERIFY REPOSITORY FILES
# ============================================================

info "Verifying UVM Panel source files..."

REQUIRED_FILES=(
    "uvm.py"
    "api.py"
    "magic.py"
    "node.py"
    "requirements.txt"
)

for FILE in "${REQUIRED_FILES[@]}"; do

    if [[ -f "${INSTALL_DIR}/${FILE}" ]]; then
        ok "Found ${FILE}"
    else
        warn "Missing ${FILE}"
    fi

done

if [[ ! -f "${INSTALL_DIR}/uvm.py" ]]; then
    die "uvm.py was not found in the UVM Panel repository."
fi

# ============================================================
# PYTHON ENVIRONMENT
# ============================================================

line
info "Creating Python virtual environment..."

python3 -m venv "${INSTALL_DIR}/.venv"

source "${INSTALL_DIR}/.venv/bin/activate"

"${INSTALL_DIR}/.venv/bin/python" -m pip install \
    --upgrade pip setuptools wheel \
    -q

ok "Python virtual environment created."

# ============================================================
# PYTHON REQUIREMENTS
# ============================================================

if [[ -f "${INSTALL_DIR}/requirements.txt" ]]; then

    info "Installing requirements.txt..."

    "${INSTALL_DIR}/.venv/bin/pip" install \
        -r "${INSTALL_DIR}/requirements.txt" \
        -q

    ok "requirements.txt installed."

else

    warn "requirements.txt not found."

fi

# ============================================================
# REQUIRED RUNTIME PACKAGES
# ============================================================

info "Installing required runtime packages..."

"${INSTALL_DIR}/.venv/bin/pip" install \
    flask \
    flask-login \
    flask-socketio \
    requests \
    paramiko \
    cryptography \
    hypercorn \
    psutil \
    pillow \
    werkzeug \
    -q

ok "Runtime packages installed."

# ============================================================
# TEMPLATES DIRECTORY
# ============================================================

info "Checking UVM Panel templates..."

mkdir -p "${INSTALL_DIR}/templates"

TEMPLATE_COUNT="$(
    find "${INSTALL_DIR}/templates" \
        -type f \
        2>/dev/null \
        | wc -l
)"

ok "Template directory ready (${TEMPLATE_COUNT} files detected)."

# ============================================================
# CREATE DATA DIRECTORIES
# ============================================================

info "Preparing UVM Panel directories..."

mkdir -p "${INSTALL_DIR}/backups"
mkdir -p "${INSTALL_DIR}/static"
mkdir -p "${INSTALL_DIR}/static/uploads"
mkdir -p "${INSTALL_DIR}/logs"

touch "${LOG_FILE}"

chmod 755 "${INSTALL_DIR}"
chmod 755 "${INSTALL_DIR}/backups"
chmod 755 "${INSTALL_DIR}/static"
chmod 755 "${INSTALL_DIR}/static/uploads"

ok "UVM Panel directories prepared."

# ============================================================
# PYTHON IMPORT CHECK
# ============================================================

info "Checking UVM Panel Python imports..."

if "${INSTALL_DIR}/.venv/bin/python" -m py_compile \
    "${INSTALL_DIR}/uvm.py"; then

    ok "uvm.py syntax check passed."

else

    die "uvm.py contains Python syntax errors."

fi

# ============================================================
# SYSTEMD SERVICE
# ============================================================

line
info "Creating UVM Panel systemd service..."

cat > "/etc/systemd/system/${SERVICE_NAME}.service" << EOF
[Unit]
Description=UVM Panel Service
Documentation=https://github.com/${GITHUB_USERNAME}/${GITHUB_REPO_NAME}
After=network-online.target
Wants=network-online.target

[Service]
Type=simple

User=root
Group=root

WorkingDirectory=${INSTALL_DIR}

Environment="PYTHONUNBUFFERED=1"
Environment="PYTHONDONTWRITEBYTECODE=1"

Environment="PATH=${INSTALL_DIR}/.venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin"

ExecStart=${INSTALL_DIR}/.venv/bin/python ${INSTALL_DIR}/uvm.py

Restart=always
RestartSec=5

TimeoutStartSec=60
TimeoutStopSec=30

StandardOutput=append:${LOG_FILE}
StandardError=append:${LOG_FILE}

[Install]
WantedBy=multi-user.target
EOF

chmod 644 \
    "/etc/systemd/system/${SERVICE_NAME}.service"

systemctl daemon-reload

systemctl enable \
    "${SERVICE_NAME}" \
    >/dev/null 2>&1

ok "Systemd service created."

# ============================================================
# START UVM PANEL
# ============================================================

info "Starting UVM Panel..."

systemctl restart "${SERVICE_NAME}"

sleep 3

# ============================================================
# SERVICE CHECK
# ============================================================

if systemctl is-active --quiet "${SERVICE_NAME}"; then

    ok "UVM Panel service is running."

else

    error "UVM Panel failed to start."

    echo
    echo "============================================================"
    echo "UVM PANEL SERVICE LOG"
    echo "============================================================"

    journalctl \
        -u "${SERVICE_NAME}" \
        --no-pager \
        -n 50 \
        || true

    echo
    echo "Log file:"
    echo "${LOG_FILE}"

    die "UVM Panel service startup failed."

fi

# ============================================================
# PORT CHECK
# ============================================================

info "Checking panel port..."

if ss -lntp 2>/dev/null | grep -q ':5000'; then
    ok "UVM Panel is listening on port 5000."
else
    warn "Port 5000 is not currently detected."
fi

# ============================================================
# PUBLIC IP
# ============================================================

info "Detecting public IP..."

PUBLIC_IP="$(
    curl \
        -4 \
        -fsS \
        --max-time 5 \
        "https://api.ipify.org" \
        2>/dev/null \
        || true
)"

if [[ -z "${PUBLIC_IP}" ]]; then

    PUBLIC_IP="$(
        hostname -I \
        2>/dev/null \
        | awk '{print $1}'
    )"

fi

if [[ -z "${PUBLIC_IP}" ]]; then
    PUBLIC_IP="YOUR_SERVER_IP"
fi

# ============================================================
# FINAL STATUS
# ============================================================

clear

echo -e "${GREEN}"

echo "╔════════════════════════════════════════════════════════════╗"
echo "║                                                            ║"
echo "║              UVM PANEL INSTALLATION SUCCESSFUL             ║"
echo "║                                                            ║"
echo "╚════════════════════════════════════════════════════════════╝"

echo

echo "  Panel URL       : http://${PUBLIC_IP}"
echo "  Internal Port   : 5000"
echo "  Install Dir     : ${INSTALL_DIR}"
echo "  Main File       : ${INSTALL_DIR}/uvm.py"
echo "  Service         : ${SERVICE_NAME}"
echo "  Log File        : ${LOG_FILE}"
echo
echo "  GitHub Repo     : ${GITHUB_USERNAME}/${GITHUB_REPO_NAME}"

echo

echo "  Service Commands:"
echo "    systemctl status ${SERVICE_NAME}"
echo "    systemctl restart ${SERVICE_NAME}"
echo "    systemctl stop ${SERVICE_NAME}"
echo "    systemctl start ${SERVICE_NAME}"
echo "    journalctl -u ${SERVICE_NAME} -f"

echo

echo -e "${NC}"

ok "UVM Panel installation completed."
