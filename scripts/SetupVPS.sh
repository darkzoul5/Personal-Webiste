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

# Ask if user wants to set up swap
read -p "Do you want to set up swap? (y/n): " setup_swap
if [[ "$setup_swap" == "y" ]]; then
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
else
    info "Swap setup skipped."
fi

info "Setting up User 'dark_zoul'..."

# Check if 'dark_zoul' user exists
if id "dark_zoul" &>/dev/null; then
    ok "User 'dark_zoul' already exists."
else
    useradd -m -s /bin/bash dark_zoul
    ok "User 'dark_zoul' created."
fi

# Copy SSH keys from current user to dark_zoul if authorized_keys exists
if [[ -f "$HOME/.ssh/authorized_keys" ]]; then
    mkdir -p /home/dark_zoul/.ssh
    cp "$HOME/.ssh/authorized_keys" /home/dark_zoul/.ssh/authorized_keys
    chown -R dark_zoul:dark_zoul /home/dark_zoul/.ssh
    chmod 700 /home/dark_zoul/.ssh
    chmod 600 /home/dark_zoul/.ssh/authorized_keys
    ok "SSH keys copied to 'dark_zoul'."
else
    warn "No SSH authorized_keys found in current user."
fi

# Set password for dark_zoul (required for sudo)
echo "Set a password for 'dark_zoul' (needed for sudo commands):"
passwd dark_zoul

# Add dark_zoul to sudoers
SUDOERS_FILE="/etc/sudoers.d/dark_zoul"
if [[ -f "$SUDOERS_FILE" ]] && grep -q "^dark_zoul" "$SUDOERS_FILE"; then
    ok "User 'dark_zoul' is already in sudoers."
else
    # Create file with tee to ensure it's written correctly
    echo "dark_zoul ALL=(ALL) ALL" | tee "$SUDOERS_FILE" > /dev/null
    chmod 440 "$SUDOERS_FILE"
    
    # Validate the sudoers file syntax
    if visudo -c -f "$SUDOERS_FILE" >/dev/null 2>&1; then
        ok "User 'dark_zoul' added to sudoers."
    else
        err "Failed to add dark_zoul to sudoers (syntax error)."
        rm "$SUDOERS_FILE"
        exit 1
    fi
fi

info "Hardening SSH Configuration..."

sshd_config_path="/etc/ssh/sshd_config"
backup_path="/etc/ssh/sshd_config.bak"

changed=false

# Backup config (once)
if [[ ! -f "$backup_path" ]]; then
    cp "$sshd_config_path" "$backup_path"
    info "Created backup at $backup_path"
else
    info "Backup already exists"
fi

# Helper function to set SSH config parameter
set_ssh_config() {
    local param="$1"
    local value="$2"
    local config="$3"
    
    if grep -qi "^#\?${param}" "$config"; then
        sed -i "s/^#\?${param}\s.*/$(echo "$param $value" | sed 's/[&/\]/\\&/g')/" "$config"
    else
        echo "$param $value" >> "$config"
    fi
    info "Set $param to $value"
    changed=true
}

# Disable PasswordAuthentication
if ! grep -q "^PasswordAuthentication no" "$sshd_config_path"; then
    set_ssh_config "PasswordAuthentication" "no" "$sshd_config_path"
else
    info "PasswordAuthentication already set to no"
fi

# Disable PermitRootLogin
if ! grep -q "^PermitRootLogin no" "$sshd_config_path"; then
    set_ssh_config "PermitRootLogin" "no" "$sshd_config_path"
else
    info "PermitRootLogin already set to no"
fi

# Enable PubkeyAuthentication
if ! grep -q "^PubkeyAuthentication yes" "$sshd_config_path"; then
    set_ssh_config "PubkeyAuthentication" "yes" "$sshd_config_path"
else
    info "PubkeyAuthentication already enabled"
fi

# Disable empty passwords
if ! grep -q "^PermitEmptyPasswords no" "$sshd_config_path"; then
    set_ssh_config "PermitEmptyPasswords" "no" "$sshd_config_path"
else
    info "PermitEmptyPasswords already disabled"
fi

# Disable X11Forwarding
if ! grep -q "^X11Forwarding no" "$sshd_config_path"; then
    set_ssh_config "X11Forwarding" "no" "$sshd_config_path"
else
    info "X11Forwarding already disabled"
fi

# Disable Agent Forwarding
if ! grep -q "^AllowAgentForwarding no" "$sshd_config_path"; then
    set_ssh_config "AllowAgentForwarding" "no" "$sshd_config_path"
else
    info "AllowAgentForwarding already disabled"
fi

# Disable TCP Forwarding
if ! grep -q "^AllowTcpForwarding no" "$sshd_config_path"; then
    set_ssh_config "AllowTcpForwarding" "no" "$sshd_config_path"
else
    info "AllowTcpForwarding already disabled"
fi

# Set MaxAuthTries
if ! grep -q "^MaxAuthTries 3" "$sshd_config_path"; then
    set_ssh_config "MaxAuthTries" "3" "$sshd_config_path"
else
    info "MaxAuthTries already limited to 3"
fi

# Set MaxSessions
if ! grep -q "^MaxSessions 5" "$sshd_config_path"; then
    set_ssh_config "MaxSessions" "5" "$sshd_config_path"
else
    info "MaxSessions already limited to 5"
fi

# Set ClientAlive settings (keep-alive)
if ! grep -q "^ClientAliveInterval 300" "$sshd_config_path"; then
    set_ssh_config "ClientAliveInterval" "300" "$sshd_config_path"
else
    info "ClientAliveInterval already set to 300"
fi

if ! grep -q "^ClientAliveCountMax 2" "$sshd_config_path"; then
    set_ssh_config "ClientAliveCountMax" "2" "$sshd_config_path"
else
    info "ClientAliveCountMax already set to 2"
fi

# Validate SSH config syntax before restarting
info "Validating SSH configuration..."
if sshd -t >/dev/null 2>&1; then
    info "SSH configuration syntax is valid"
else
    err "SSH configuration has syntax errors. Restoring backup..."
    cp "$backup_path" "$sshd_config_path"
    exit 1
fi

# Restart if changes were made
if $changed; then
    info "Restarting SSH service..."
    if systemctl restart ssh >/dev/null 2>&1; then
        ok "SSH service restarted successfully"
    else
        err "SSH restart failed. Restoring backup..."
        cp "$backup_path" "$sshd_config_path"
        systemctl restart ssh
        exit 1
    fi
else
    info "SSH configuration already hardened, no restart needed"
fi

ok "SSH hardening complete."

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
if command -v docker &>/dev/null; then
    if id -nG dark_zoul | grep -qw "docker"; then
        ok "User 'dark_zoul' is already in the Docker group."
    else
        usermod -aG docker dark_zoul
        ok "User 'dark_zoul' added to Docker group."
    fi
fi

if command -v docker &>/dev/null; then
    info "Installing Edge Agent..."

    # Prompt for Edge ID and Key
    read -p "Enter Edge ID: " edge_id
    read -p "Enter Edge Key: " edge_key

    # Download and run the script for Portainer Agent, passing the credentials as arguments
    warn "Downloading and executing the Edge Agent install script..."
    if curl -fsSL "https://portfolio.darkzoul.org/scripts/EdgeAgentUpdate.sh" | bash -s "$edge_id" "$edge_key"; then
        ok "Edge Agent installed successfully."
    else
        err "Edge Agent installation failed."
    fi
fi

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

# Install tree if not present
if command -v tree &>/dev/null; then
    ok "tree is already installed."
else
    apt-get install -y -qq tree >/dev/null 2>&1
    ok "tree installed successfully."
fi

ok "Setup Complete!"
