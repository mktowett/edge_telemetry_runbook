#!/bin/bash
# =============================================================================
# EdgeTelemetry - Get Started Script
# Validates mount points, installs all required software for deployment
# Target OS: Ubuntu 24.04 LTS
# Usage:     sudo bash getstarted.sh
# =============================================================================

set -e

# -----------------------------------------------------------------------------
# Colours
# -----------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC}    $1"; }
success() { echo -e "${GREEN}[OK]${NC}      $1"; }
warning() { echo -e "${YELLOW}[WARN]${NC}    $1"; }
error()   { echo -e "${RED}[ERROR]${NC}   $1"; exit 1; }
section() {
  echo ""
  echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║${NC}  $1"
  echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
}

if [ "$EUID" -ne 0 ]; then
  error "Please run this script with sudo: sudo bash getstarted.sh"
fi

INVOKING_USER=${SUDO_USER:-$USER}

# =============================================================================
# SECTION 1 — Pre-flight Checks
# =============================================================================
section "Pre-flight Checks"

if [ -f /etc/os-release ]; then
  . /etc/os-release
  if [[ "$ID" != "ubuntu" ]]; then
    warning "Designed for Ubuntu — detected: $PRETTY_NAME. Proceeding anyway..."
  else
    success "OS: $PRETTY_NAME"
  fi
else
  warning "Cannot detect OS. Proceeding anyway..."
fi

TOTAL_RAM=$(free -g | awk '/^Mem:/{print $2}')
if [ "$TOTAL_RAM" -lt 4 ]; then
  warning "RAM: ${TOTAL_RAM}GB detected — 4GB+ recommended."
else
  success "RAM: ${TOTAL_RAM}GB total"
fi

SWAP_GB=$(free -g | awk '/^Swap:/{print $2}')
if [ "$SWAP_GB" -lt 16 ]; then
  warning "Swap: ${SWAP_GB}GB — 16GB recommended (equal to RAM)."
else
  success "Swap: ${SWAP_GB}GB configured"
fi

# =============================================================================
# SECTION 2 — Mount Point Validation & Directory Creation
# =============================================================================
section "Mount Point Validation"

MOUNT_PATHS=("/" "/var" "/opt" "/home" "/tmp" "/data")
MOUNT_MIN_GBS=("40" "100" "80" "40" "20" "200")
MOUNT_PURPOSES=(
  "Root filesystem"
  "Application logs and telemetry data"
  "Docker Engine, Compose, and custom packages"
  "User files and configurations"
  "Temporary files"
  "Edge telemetry data storage, buffer, and archive"
)

MOUNT_WARNINGS=false

for i in "${!MOUNT_PATHS[@]}"; do
  MOUNT="${MOUNT_PATHS[$i]}"
  MIN_GB="${MOUNT_MIN_GBS[$i]}"
  PURPOSE="${MOUNT_PURPOSES[$i]}"

  if [ ! -d "$MOUNT" ]; then
    warning "$MOUNT does not exist — creating directory..."
    mkdir -p "$MOUNT"
    success "Created: $MOUNT  ($PURPOSE)"
    warning "  ⚠  $MOUNT is a plain directory, NOT a dedicated mount point."
    warning "     Provision and mount a dedicated volume (${MIN_GB}GB) at $MOUNT for production."
    MOUNT_WARNINGS=true
    continue
  fi

  IS_MOUNTED=false
  if [ "$MOUNT" = "/" ]; then
    IS_MOUNTED=true
  elif grep -qs " ${MOUNT} " /proc/mounts; then
    IS_MOUNTED=true
  fi

  if [ "$IS_MOUNTED" = false ]; then
    warning "$MOUNT exists but has NO dedicated volume (sharing root filesystem)."
    warning "  Purpose:          $PURPOSE"
    warning "  Recommended size: ${MIN_GB}GB"
    warning "  Action needed:    Provision and mount a dedicated volume at $MOUNT."
    MOUNT_WARNINGS=true
  else
    AVAIL_GB=$(df "$MOUNT" --output=avail -BG 2>/dev/null | tail -1 | tr -d 'G ')
    TOTAL_GB=$(df "$MOUNT" --output=size  -BG 2>/dev/null | tail -1 | tr -d 'G ')
    if [ "$AVAIL_GB" -lt "$MIN_GB" ]; then
      warning "$MOUNT — only ${AVAIL_GB}GB free of ${TOTAL_GB}GB  (min required: ${MIN_GB}GB)"
      warning "  Purpose: $PURPOSE"
      MOUNT_WARNINGS=true
    else
      success "$MOUNT — ${AVAIL_GB}GB free / ${TOTAL_GB}GB total  [min: ${MIN_GB}GB]  |  $PURPOSE"
    fi
  fi
done

echo ""
info "Current disk layout:"
echo ""
printf "  %-18s %-8s %-8s %-8s %s\n" "Mount" "Size" "Used" "Avail" "Use%"
printf "  %-18s %-8s %-8s %-8s %s\n" "─────────────────" "────────" "────────" "────────" "────"
for MOUNT in "${MOUNT_PATHS[@]}"; do
  if [ -d "$MOUNT" ]; then
    LINE=$(df -h "$MOUNT" 2>/dev/null | tail -1)
    TOTAL=$(echo "$LINE" | awk '{print $2}')
    USED=$(echo  "$LINE" | awk '{print $3}')
    AVAIL=$(echo "$LINE" | awk '{print $4}')
    PCT=$(echo   "$LINE" | awk '{print $5}')
    printf "  %-18s %-8s %-8s %-8s %s\n" "$MOUNT" "$TOTAL" "$USED" "$AVAIL" "$PCT"
  else
    printf "  %-18s %s\n" "$MOUNT" "(not found)"
  fi
done
echo ""

if [ "$MOUNT_WARNINGS" = true ]; then
  warning "Mount point issues detected — resolve before going to production."
fi

# =============================================================================
# SECTION 3 — System Update
# =============================================================================
section "Step 1 — Updating System Packages"

info "Running apt-get update and upgrade..."
apt-get update -y
apt-get upgrade -y
success "System packages updated"

# =============================================================================
# SECTION 4 — Install Utilities
# =============================================================================
section "Step 2 — Installing Utilities"

info "Installing make, unzip, curl, net-tools..."
apt-get install -y make unzip curl net-tools ca-certificates gnupg lsb-release
success "Utilities installed (make, unzip, curl, net-tools)"

# =============================================================================
# SECTION 5 — Install Docker
# =============================================================================
section "Step 3 — Installing Docker"

if command -v docker &> /dev/null; then
  warning "Docker already installed: $(docker --version)"
  info "Skipping Docker installation."
else
  info "Adding Docker GPG key..."
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
    gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg

  info "Adding Docker apt repository..."
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
    https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | \
    tee /etc/apt/sources.list.d/docker.list > /dev/null

  info "Installing Docker Engine and Compose plugin..."
  apt-get update -y
  apt-get install -y docker-ce docker-ce-cli containerd.io \
                     docker-buildx-plugin docker-compose-plugin

  success "Docker installed:         $(docker --version)"
  success "Docker Compose installed: $(docker compose version)"
fi

if id -nG "$INVOKING_USER" | grep -qw docker; then
  info "User '$INVOKING_USER' is already in the docker group."
else
  usermod -aG docker "$INVOKING_USER"
  success "User '$INVOKING_USER' added to the docker group."
  warning "Run 'newgrp docker' or log out/in before using Docker commands."
fi

systemctl enable docker
systemctl start docker
success "Docker service enabled and running"

# =============================================================================
# SECTION 6 — Install Nginx
# =============================================================================
section "Step 4 — Installing Nginx"

if command -v nginx &> /dev/null; then
  warning "Nginx already installed: $(nginx -v 2>&1)"
  info "Skipping Nginx installation."
else
  info "Installing Nginx..."
  apt-get install -y nginx
  success "Nginx installed: $(nginx -v 2>&1)"
fi

systemctl enable nginx
systemctl start nginx
success "Nginx service enabled and running"

# =============================================================================
# SECTION 7 — Port Availability Check
# =============================================================================
section "Step 5 — Checking Port Availability"

PORT_NUMS=(80 443 8001 8002 8003 8080 6379)
PORT_LABELS=(
  "Nginx HTTP"
  "Nginx HTTPS"
  "Telemetry Collector"
  "Telemetry Processor"
  "RUM Analytics API"
  "Kafka UI"
  "Redis"
)
ALL_PORTS_CLEAR=true

for i in "${!PORT_NUMS[@]}"; do
  PORT="${PORT_NUMS[$i]}"
  LABEL="${PORT_LABELS[$i]}"
  if ss -tulpn 2>/dev/null | grep -q ":${PORT} "; then
    warning "Port $PORT ($LABEL) is already in use!"
    ALL_PORTS_CLEAR=false
  else
    success "Port $PORT ($LABEL) is free"
  fi
done

if [ "$ALL_PORTS_CLEAR" = false ]; then
  warning "Resolve port conflicts before deploying."
  warning "Run: sudo ss -tulpn | grep -E ':(80|443|8001|8002|8003|8080|6379)'"
else
  success "All required ports are available"
fi

# =============================================================================
# SECTION 8 — PostgreSQL Connectivity Check
# =============================================================================
section "Step 6 — PostgreSQL Connectivity Check"

info "You will need the DB host and port from your infrastructure/config team."
echo ""

if [ -z "$PG_HOST" ]; then
  read -rp "  Enter PostgreSQL host (e.g. 192.168.1.100): " PG_HOST
fi
if [ -z "$PG_PORT" ]; then
  read -rp "  Enter PostgreSQL port (default 5432): " PG_PORT
  PG_PORT="${PG_PORT:-5432}"
fi

echo ""
if nc -zv -w 5 "$PG_HOST" "$PG_PORT" 2>&1 | grep -q "succeeded\|open"; then
  success "PostgreSQL is reachable at $PG_HOST:$PG_PORT"
else
  warning "Could not reach PostgreSQL at $PG_HOST:$PG_PORT"
  warning "Check that:"
  warning "  - The DB host and port from your team are correct"
  warning "  - This server's IP is whitelisted on the database firewall"
  warning "  - Network routing between this server and the DB is configured"
  warning "Deployment can continue but processor and RUM Analytics will fail to connect."
fi

# =============================================================================
# SECTION 9 — Create Deployment Directories
# =============================================================================
section "Step 7 — Creating Deployment Directories"

# Project extract directory
DEPLOY_DIR="/opt/edgetelemetry"
if [ -d "$DEPLOY_DIR" ]; then
  warning "$DEPLOY_DIR already exists. Skipping creation."
else
  mkdir -p "$DEPLOY_DIR"
  success "Created: $DEPLOY_DIR  (project directory)"
fi
chown "$INVOKING_USER":"$INVOKING_USER" "$DEPLOY_DIR"
success "Ownership of $DEPLOY_DIR set to '$INVOKING_USER'"

# Makefile data/log directories — owned 1000:1000 for Docker compatibility
EDGE_DATA_ROOT="/opt/edge-telemetry"
for SUBDIR in data/kafka data/zookeeper data/redis logs/zookeeper logs/redis; do
  FULL_PATH="$EDGE_DATA_ROOT/$SUBDIR"
  if [ ! -d "$FULL_PATH" ]; then
    mkdir -p "$FULL_PATH"
    success "Created: $FULL_PATH"
  else
    info "$FULL_PATH already exists"
  fi
done
chown -R 1000:1000 "$EDGE_DATA_ROOT"
success "Ownership of $EDGE_DATA_ROOT set to 1000:1000 (Docker compatibility)"

# Telemetry data storage on the /data mount
DATA_DIR="/data/edgetelemetry"
if [ -d "$DATA_DIR" ]; then
  warning "$DATA_DIR already exists. Skipping creation."
else
  mkdir -p "$DATA_DIR"
  success "Created: $DATA_DIR  (telemetry data storage)"
fi
chown "$INVOKING_USER":"$INVOKING_USER" "$DATA_DIR"
success "Ownership of $DATA_DIR set to '$INVOKING_USER'"

# =============================================================================
# SECTION 10 — Final Summary
# =============================================================================
section "Installation Complete"

echo ""
echo -e "  ${GREEN}Software installed:${NC}"
echo -e "    ✓ Docker          $(docker --version)"
echo -e "    ✓ Docker Compose  $(docker compose version)"
echo -e "    ✓ Nginx           $(nginx -v 2>&1)"
echo -e "    ✓ Make            $(make --version | head -1)"
echo -e "    ✓ Unzip           $(unzip -v 2>&1 | head -1)"
echo ""
echo -e "  ${GREEN}Directories ready:${NC}"
echo -e "    ✓ $DEPLOY_DIR              (project directory)"
echo -e "    ✓ $EDGE_DATA_ROOT/data     (Kafka, Zookeeper, Redis volumes)"
echo -e "    ✓ $EDGE_DATA_ROOT/logs     (Zookeeper, Redis logs)"
echo -e "    ✓ $DATA_DIR         (telemetry data storage)"
echo ""

if [ "$MOUNT_WARNINGS" = true ] || [ "$ALL_PORTS_CLEAR" = false ]; then
  echo -e "  ${YELLOW}⚠  Warnings were raised — review output above before deploying to production.${NC}"
  echo ""
fi

echo -e "  ${CYAN}Next steps:${NC}"
echo -e "    1.  From your local machine, copy the zip to the server:"
echo -e "        ${BLUE}scp EdgeTelemetryDeployment.zip user@<server-ip>:/opt/edgetelemetry/${NC}"
echo -e "    2.  Extract the project:"
echo -e "        ${BLUE}cd /opt/edgetelemetry && unzip EdgeTelemetryDeployment.zip${NC}"
echo -e "    3.  Enter the project directory:"
echo -e "        ${BLUE}cd EdgeTelemetryDeployment${NC}"
echo -e "    4.  Create the config file:"
echo -e "        ${BLUE}cp configs/processor-config.env.example configs/processor-config.env${NC}"
echo -e "    5.  Paste in values provided by your infrastructure team:"
echo -e "        ${BLUE}nano configs/processor-config.env${NC}"
echo -e "         → Set DATABASE_URL, EDGE_JWT_SECRET, and all other required values"
echo -e "    6.  Deploy:"
echo -e "        ${BLUE}make prod-deploy${NC}"
echo ""
echo -e "  ${YELLOW}NOTE:${NC} If you were added to the docker group during this run, run:"
echo -e "        ${BLUE}newgrp docker${NC}  (or log out and back in)"
echo ""
