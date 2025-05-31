#!/bin/bash

# Colors
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
RED="\033[1;31m"
NC="\033[0m"

# Log Functions
info() { echo -e "${YELLOW}[INFO]${NC} $1"; }
ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
err()  { echo -e "${RED}[ERROR]${NC} $1"; }

# Ensure the script runs as root
if [[ $EUID -ne 0 ]]; then
    err "This script must be run as root. Try using sudo."
    exit 1
fi

info "Checking and Setting up Swap..."

# Ask for the size of the swap file in GB
read -p "Enter the swap size in GB: " swap_size
if ! [[ "$swap_size" =~ ^[0-9]+$ ]]; then
    err "Invalid input. Please enter a valid number."
    exit 1
fi

# Check if swap already exists
if swapon --show | grep -q "/swapfile"; then
    ok "Swap already set up."
else
    warn "Creating swap..."
    swapoff -a 2>/dev/null
    fallocate -l ${swap_size}G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo "/swapfile none swap sw 0 0" >> /etc/fstab
    ok "Swap setup complete."
fi

info "Setting up User 'dark_zoul'..."

# Check if 'dark_zoul' user exists
if id "dark_zoul" &>/dev/null; then
    ok "User 'dark_zoul' already exists."
else
    useradd -m -s /bin/bash dark_zoul
    ok "User 'dark_zoul' created."
    echo "Set a password for 'dark_zoul':"
    passwd dark_zoul
fi

info "Hardening SSH Configuration..."

sshd_config_path="/etc/ssh/sshd_config"
backup_path="/etc/ssh/sshd_config.bak"

changed=false

# Backup config (once)
[[ ! -f "$backup_path" ]] && cp "$sshd_config_path" "$backup_path"

# Disable PasswordAuthentication
if grep -Eq "^#?PasswordAuthentication\s+yes" "$sshd_config_path"; then
    sed -i 's/^#\?PasswordAuthentication\s\+yes/PasswordAuthentication no/' "$sshd_config_path"
    changed=true
elif ! grep -q "^PasswordAuthentication no" "$sshd_config_path"; then
    echo "PasswordAuthentication no" >> "$sshd_config_path"
    changed=true
fi

# Disable PermitRootLogin
if grep -Eq "^#?PermitRootLogin\s+yes" "$sshd_config_path"; then
    sed -i 's/^#\?PermitRootLogin\s\+yes/PermitRootLogin no/' "$sshd_config_path"
    changed=true
elif ! grep -q "^PermitRootLogin no" "$sshd_config_path"; then
    echo "PermitRootLogin no" >> "$sshd_config_path"
    changed=true
fi

# Restart if changes were made
if $changed; then
    systemctl restart ssh && \
    ok "SSH hardened and restarted." || \
    err "SSH restart failed."
else
    ok "SSH already hardened."
fi

info "Checking for Docker Installation..."

# Install Docker if not present
if ! command -v docker &>/dev/null; then
    read -p "Docker is not installed. Do you want to install it? (y/n): " install_docker
    if [[ "$install_docker" == "y" ]]; then
        warn "Installing Docker..."
        apt-get update -qq >/dev/null 2>&1
        apt-get install -y -qq ca-certificates curl >/dev/null 2>&1
        install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
        chmod a+r /etc/apt/keyrings/docker.asc

        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
            tee /etc/apt/sources.list.d/docker.list > /dev/null

        apt-get update -qq >/dev/null 2>&1
        apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin >/dev/null 2>&1
        ok "Docker installed successfully."
    else
        warn "Docker installation skipped."
    fi
fi

# Add user to Docker group if Docker installed
if id -nG dark_zoul | grep -qw "docker"; then
    ok "User 'dark_zoul' is already in the Docker group."
elif command -v docker &>/dev/null; then
    usermod -aG docker dark_zoul
    ok "User 'dark_zoul' added to Docker group."
fi

info "Installing Edge Agent from URL..."

# Prompt for Edge ID and Key
read -p "Enter Edge ID: " edge_id
read -p "Enter Edge Key: " edge_key

# Download and run the script for Portainer Agent, passing the credentials as arguments
warn "Downloading and executing the Edge Agent install script..."
curl -fsSL "https://www.darkzoul.org/portfolio/scripts/UpdatePortainerAgent.sh" | bash -s "$edge_id" "$edge_key"

info "Installing Miscellaneous Programs..."

# Install btop if not present
if command -v btop &>/dev/null; then
    ok "btop is already installed."
else
    apt-get update -qq >/dev/null 2>&1
    apt-get install -y -qq btop >/dev/null 2>&1
    ok "btop installed successfully."
fi

# Install neofetch if not present
if command -v neofetch &>/dev/null; then
    ok "neofetch is already installed."
else
    apt-get install -y -qq neofetch >/dev/null 2>&1
    ok "neofetch installed successfully."
fi

ok "Setup Complete!"
