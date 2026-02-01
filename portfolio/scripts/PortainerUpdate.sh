#!/bin/bash

# Settings
COMPOSE_DIR="/home/dark_zoul/docker/portainer"
IMAGE_NAME="portainer/portainer-ce:lts"

# Output helper
print_msg() {
    echo -e "\n\033[1;34m[INFO]\033[0m $1"
}

cd "$COMPOSE_DIR" || {
    echo -e "\033[1;31m[ERROR]\033[0m Failed to change directory to $COMPOSE_DIR"
    exit 1
}

# Save old image ID
OLD_IMAGE_ID=$(docker inspect --format='{{.Id}}' "$IMAGE_NAME" 2>/dev/null)

print_msg "Pulling latest image for $IMAGE_NAME..."
PULL_OUTPUT=$(docker pull "$IMAGE_NAME" 2>&1)

if echo "$PULL_OUTPUT" | grep -q "Image is up to date"; then
    print_msg "Image is already up to date. No update needed."
    exit 0
else
    print_msg "New image pulled. Recreating Portainer container..."
fi

docker compose down
docker compose up -d

if [ $? -eq 0 ]; then
    print_msg "Portainer successfully updated and running."

    if [ -n "$OLD_IMAGE_ID" ]; then
        print_msg "Removing old image: $OLD_IMAGE_ID"
        docker image rm "$OLD_IMAGE_ID" >/dev/null 2>&1 && \
            print_msg "Old image removed." || \
            print_msg "Old image could not be removed (might be in use)."
    fi
else
    echo -e "\033[1;31m[ERROR]\033[0m Failed to start Portainer. Check logs with: docker compose logs"
    exit 1
fi
