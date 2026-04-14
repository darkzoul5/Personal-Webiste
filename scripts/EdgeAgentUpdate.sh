#!/bin/bash
set -euo pipefail
# Colors
BLUE="\033[1;34m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
RED="\033[1;31m"
NC="\033[0m"

info() { echo -e "${BLUE}[INFO]${NC} $1"; }
ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
err()  { echo -e "${RED}[ERROR]${NC} $1"; }

# Determine the actual user's home directory (works with sudo)
REAL_USER="${SUDO_USER:-$(whoami)}"
CONFIG_DIR=$(eval echo "~$REAL_USER")
CONFIG_FILE="$CONFIG_DIR/.portainer_edge.conf"

IMAGE_NAME="portainer/agent:lts"

# Check if EDGE_ID and EDGE_KEY are passed as arguments
if [ -z "${1:-}" ] || [ -z "${2:-}" ]; then
    # If not passed, check if config file exists and load from it
    if [ -f "$CONFIG_FILE" ]; then
        # Safely load config file using eval to handle spaces
        eval $(grep -E '^(EDGE_ID|EDGE_KEY)=' "$CONFIG_FILE" | sed "s/^/export /")
        info "Loaded EDGE_ID and EDGE_KEY from config file."
        # Validate that credentials were loaded
        if [ -z "${EDGE_ID:-}" ] || [ -z "${EDGE_KEY:-}" ]; then
            err "Config file found but EDGE_ID or EDGE_KEY is missing. Please provide valid credentials."
            exit 1
        fi
    else
        read -rp "Enter Edge ID: " EDGE_ID
        read -rsp "Enter Edge Key: " EDGE_KEY
        echo ""
        # Validate user input
        if [ -z "$EDGE_ID" ] || [ -z "$EDGE_KEY" ]; then
            err "EDGE_ID and EDGE_KEY cannot be empty."
            exit 1
        fi
    fi
else
    EDGE_ID=$1
    EDGE_KEY=$2
    info "Using EDGE_ID and EDGE_KEY passed as arguments."
    # Validate arguments
    if [ -z "$EDGE_ID" ] || [ -z "$EDGE_KEY" ]; then
        err "EDGE_ID and EDGE_KEY cannot be empty."
        exit 1
    fi
fi

info "Checking for updated image: $IMAGE_NAME"

OLD_IMAGE_ID=$(docker inspect --format='{{.Id}}' "$IMAGE_NAME" 2>/dev/null || true)

if ! PULL_OUTPUT=$(docker pull "$IMAGE_NAME" 2>&1); then
    err "Failed to pull image: $IMAGE_NAME. Check your Docker setup and internet connection."
    exit 1
fi

NEW_IMAGE_ID=$(docker inspect --format='{{.Id}}' "$IMAGE_NAME" 2>/dev/null)

if echo "$PULL_OUTPUT" | grep -q "Image is up to date"; then
    ok "Image is already up to date. No update necessary."
    exit 0
else
    if [ -z "$OLD_IMAGE_ID" ]; then
        info "Installing new Portainer Edge Agent image..."
    elif [ "$OLD_IMAGE_ID" != "$NEW_IMAGE_ID" ]; then
        info "Found a new image. Proceeding with update..."
    else
        info "Image re-pulled, but no ID change detected. Proceeding with container recreation."
    fi
fi

# Check if container is already running with current credentials (idempotency)
if docker ps --format '{{.Names}}' | grep -Eq "^portainer_edge_agent\$"; then
    RUNNING_EDGE_ID=$(docker inspect portainer_edge_agent -f '{{.Config.Env}}' | grep -oP 'EDGE_ID=\K[^ ]+')
    if [ "$RUNNING_EDGE_ID" = "$EDGE_ID" ]; then
        ok "Container already running with current credentials. Skipping recreation."
        exit 0
    fi
fi

# Stop and remove existing container (even if not running)
if docker ps -a --format '{{.Names}}' | grep -Eq "^portainer_edge_agent\$"; then
    info "Stopping and removing existing container: portainer_edge_agent"
    if docker stop portainer_edge_agent >/dev/null 2>&1; then
        info "Container stopped"
    fi
    if docker rm portainer_edge_agent >/dev/null 2>&1; then
        info "Container removed"
    else
        warn "Failed to remove container (may be in use)"
    fi
fi

info "Starting updated container: portainer_edge_agent"
docker run -d \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /var/lib/docker/volumes:/var/lib/docker/volumes \
  -v /:/host \
  -v portainer_agent_data:/data \
  --restart always \
  -e EDGE=1 \
  -e EDGE_ID="$EDGE_ID" \
  -e EDGE_KEY="$EDGE_KEY" \
  -e EDGE_INSECURE_POLL=1 \
  --name portainer_edge_agent \
  "$IMAGE_NAME"

if [ $? -eq 0 ]; then
    # Verify container is actually running
    if docker ps --format '{{.Names}}' | grep -Eq "^portainer_edge_agent\$"; then
        ok "Container started successfully and is running."
    else
        err "Container created but is not running. Check logs with: docker logs portainer_edge_agent"
        exit 1
    fi

    # Save credentials only if config file doesn't exist
    if [ ! -f "$CONFIG_FILE" ]; then
        info "Saving EDGE_ID and EDGE_KEY to $CONFIG_FILE"
        {
            echo "EDGE_ID=\"$EDGE_ID\""
            echo "EDGE_KEY=\"$EDGE_KEY\""
        } > "$CONFIG_FILE"
        chmod 600 "$CONFIG_FILE"
        info "Config file saved with restricted permissions (600)"
    fi

    if [ -n "$OLD_IMAGE_ID" ] && [ "$OLD_IMAGE_ID" != "$NEW_IMAGE_ID" ]; then
        info "Removing old image: $OLD_IMAGE_ID"
        docker image rm "$OLD_IMAGE_ID" >/dev/null 2>&1 && \
            ok "Old image removed." || \
            warn "Old image could not be removed (might be in use or already gone)."
    fi

    ok "Update process completed successfully."
else
    err "Failed to start new container. Old image has not been removed."
    exit 1
fi
