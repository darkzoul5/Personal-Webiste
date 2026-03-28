#!/bin/bash
set -euo pipefail
# Colors
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
RED="\033[1;31m"
NC="\033[0m"

info() { echo -e "${YELLOW}[INFO]${NC} $1"; }
ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
err()  { echo -e "${RED}[ERROR]${NC} $1"; }

IMAGE_NAME="portainer/agent:lts"
CONFIG_FILE="$HOME/.portainer_edge.conf"

# Check if EDGE_ID and EDGE_KEY are passed as arguments
if [ -z "$1" ] || [ -z "$2" ]; then
    # If not passed, check if config file exists and load from it
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
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
    fi
else
    EDGE_ID=$1
    EDGE_KEY=$2
    info "Using EDGE_ID and EDGE_KEY passed as arguments."
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

if docker ps -a --format '{{.Names}}' | grep -Eq "^portainer_edge_agent\$"; then
    info "Stopping and removing existing container: portainer_edge_agent"
    docker stop portainer_edge_agent
    docker rm portainer_edge_agent
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
    ok "Container started successfully."

    # Save credentials only if config file doesn't exist
    if [ ! -f "$CONFIG_FILE" ]; then
        info "Saving EDGE_ID and EDGE_KEY to $CONFIG_FILE"
        {
            echo "EDGE_ID=\"$EDGE_ID\""
            echo "EDGE_KEY=\"$EDGE_KEY\""
        } > "$CONFIG_FILE"
        chmod 600 "$CONFIG_FILE"
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
