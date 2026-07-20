#!/usr/bin/env bash
set -Eeuo pipefail

VERBOSE=false

if [[ "${1:-}" == "--verbose" ]]; then
    VERBOSE=true
fi

echo "Requesting sudo access..."
sudo -v

run_with_indicator() {
    if $VERBOSE; then
        "$@"
        return
    fi

    "$@" >/tmp/aptupdate.log 2>&1 &
    local pid=$!
    local symbols=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
    local i=0

    while kill -0 "$pid" 2>/dev/null; do
        printf "\r${symbols[$i]} Working..."
        i=$(( (i + 1) % ${#symbols[@]} ))
        sleep 0.2
    done

    wait "$pid"
    printf "\r✓ Done.      \n"
}

export DEBIAN_FRONTEND=noninteractive

echo
echo "[1/4] Updating package lists..."
run_with_indicator sudo apt-get update -qq

echo "[2/4] Upgrading installed packages..."
run_with_indicator sudo apt-get upgrade -y -qq

echo "[3/4] Removing unused packages..."
run_with_indicator sudo apt-get autoremove -y -qq

echo "[4/4] Cleaning package cache..."
run_with_indicator sudo apt-get autoclean -qq

echo
echo "✓ System packages updated successfully."

if [[ -f /var/run/reboot-required ]]; then
    echo "⚠ A system reboot is required."
fi
