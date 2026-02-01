#!/usr/bin/env bash
set -euo pipefail

# Colors
GREEN="\e[32m"
YELLOW="\e[33m"
RED="\e[31m"
CYAN="\e[36m"
BOLD="\e[1m"
RESET="\e[0m"

# Get latest available NVIDIA server driver from apt
latest_driver_pkg=$(apt-cache search --names-only '^nvidia-driver-[0-9]+-server$' \
    | awk '{print $1}' \
    | sort -V \
    | tail -n 1)

# Check currently installed driver
current_driver_pkg=$(dpkg -l | awk '/nvidia-driver-[0-9]+-server/ {print $2}' | sort -V | tail -n 1)

echo -e "${CYAN}${BOLD}Checking NVIDIA server driver versions...${RESET}"
echo -e "Latest available: ${GREEN}$latest_driver_pkg${RESET}"
if [[ -n "$current_driver_pkg" ]]; then
    echo -e "Currently installed: ${YELLOW}$current_driver_pkg${RESET}"
else
    echo -e "${RED}No NVIDIA server driver currently installed.${RESET}"
fi
echo

# If already on latest, exit
if [[ "$current_driver_pkg" == "$latest_driver_pkg" ]]; then
    echo -e "${GREEN}You already have the latest NVIDIA server driver installed.${RESET}"
    exit 0
fi

# Ask user for confirmation
read -rp "$(echo -e "${BOLD}Do you want to install/upgrade to ${GREEN}$latest_driver_pkg${RESET}${BOLD}? [y/N]: ${RESET}")" answer
if [[ "$answer" =~ ^[Yy]$ ]]; then
    echo -e "${CYAN}Installing $latest_driver_pkg...${RESET}"
    sudo apt update
    sudo apt install -y "$latest_driver_pkg"
    echo -e "${GREEN}Driver installation complete. Please reboot to apply changes.${RESET}"
else
    echo -e "${YELLOW}Upgrade canceled by user.${RESET}"
fi
