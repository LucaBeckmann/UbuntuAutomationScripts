#!/bin/bash

LOGFILE="/var/log/user_setup.log"

# Logging function
log() {
    local message="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') : $message" | tee -a "$LOGFILE"
}

# Ensure the script is run as root
if [ "$(id -u)" -ne 0 ]; then
    log "ERROR: This script must be run as root."
    exit 1
fi

set -e

log "===================================================="
log "==== Step 1: Set system timezone               ===="
log "===================================================="
while true; do
    read -rp "Enter your desired timezone (e.g., Europe/Berlin): " TIMEZONE
    if timedatectl list-timezones | grep -qx "$TIMEZONE"; then
        timedatectl set-timezone "$TIMEZONE"
        log "Timezone set to $TIMEZONE."
        break
    else
        echo "Invalid timezone. Please try again."
    fi
done

log "===================================================="
log "==== Step 2: Set hostname                      ===="
log "===================================================="
read -rp "Enter a hostname for this server: " CUSTOM_HOSTNAME
log "Setting hostname to: $CUSTOM_HOSTNAME"
hostnamectl set-hostname "$CUSTOM_HOSTNAME"

# Save hostname for use in MOTD
echo "$CUSTOM_HOSTNAME" > /etc/motd_hostname.conf
chmod 644 /etc/motd_hostname.conf
log "Hostname saved to /etc/motd_hostname.conf."

log "===================================================="
log "==== Step 3: User setup                        ===="
log "===================================================="

# Prompt for username
read -rp "Enter desired username: " USERNAME
log "Username to create: $USERNAME"

# Prompt for password twice
while true; do
    read -rsp "Enter password: " PASSWORD1
    echo
    read -rsp "Confirm password: " PASSWORD2
    echo
    if [ "$PASSWORD1" = "$PASSWORD2" ]; then
        PASSWORD="$PASSWORD1"
        log "Password confirmation successful."
        break
    else
        log "Password mismatch. Asking again."
        echo "Passwords do not match. Please try again."
    fi
done

# GitHub username for SSH keys
read -rp "GitHub username to fetch SSH keys from: " GITHUB_USER
log "GitHub user for SSH keys: $GITHUB_USER"

log "===================================================="
log "==== Step 4: Create user $USERNAME             ===="
log "===================================================="

if id "$USERNAME" &>/dev/null; then
    log "User $USERNAME already exists."
else
    log "Creating user $USERNAME..."
    useradd -m -s /bin/bash "$USERNAME"
    echo "$USERNAME:$PASSWORD" | chpasswd
    log "User $USERNAME created and password set."
fi

log "Adding $USERNAME to the sudo group..."
usermod -aG sudo "$USERNAME"
log "$USERNAME now has sudo privileges."

log "===================================================="
log "==== Step 5: Configure SSH access              ===="
log "===================================================="

USER_HOME="/home/$USERNAME"
SSH_DIR="$USER_HOME/.ssh"
AUTHORIZED_KEYS="$SSH_DIR/authorized_keys"

mkdir -p "$SSH_DIR"
touch "$AUTHORIZED_KEYS"
chmod 700 "$SSH_DIR"
chmod 600 "$AUTHORIZED_KEYS"
chown -R "$USERNAME:$USERNAME" "$SSH_DIR"

log "Fetching SSH keys from GitHub user '$GITHUB_USER'..."
curl -s "https://github.com/$GITHUB_USER.keys" | while read -r key; do
    if grep -Fxq "$key" "$AUTHORIZED_KEYS"; then
        log "Key already present – skipping."
    else
        echo "$key" >> "$AUTHORIZED_KEYS"
        log "Key added for $USERNAME."
    fi
done

chown "$USERNAME:$USERNAME" "$AUTHORIZED_KEYS"

log "===================================================="
log "==== Step 6: Harden SSH configuration          ===="
log "===================================================="

cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
log "Backup of sshd_config saved to /etc/ssh/sshd_config.bak"

sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#\?ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#\?UsePAM.*/UsePAM no/' /etc/ssh/sshd_config
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config

if grep -q "^#\?PubkeyAuthentication" /etc/ssh/sshd_config; then
    sed -i 's/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
else
    echo "PubkeyAuthentication yes" >> /etc/ssh/sshd_config
fi
log "SSH configuration updated to allow only key-based login."

conf_dir="/etc/ssh/sshd_config.d"
conf_updated=false

shopt -s nullglob
for file in "$conf_dir"/*.conf; do
    if grep -q "^PasswordAuthentication" "$file"; then
        sed -i 's/^PasswordAuthentication.*/PasswordAuthentication no/' "$file"
        log "PasswordAuthentication disabled in $file"
        conf_updated=true
    fi
done
shopt -u nullglob

if [ "$conf_updated" = false ]; then
    echo -e "# Disable password authentication\nPasswordAuthentication no" > "$conf_dir/10-disable-password.conf"
    log "Created $conf_dir/10-disable-password.conf to disable password login."
fi

systemctl restart ssh
log "SSH service restarted. Password logins are now disabled."

log "===================================================="
log "==== Step 7: Setup login MOTD script           ===="
log "===================================================="

MOTD_SCRIPT="/etc/profile.d/login_motd.sh"

cat <<'EOF' > "$MOTD_SCRIPT"
#!/bin/bash

# Load server name
if [ -f /etc/motd_hostname.conf ]; then
    SERVER_NAME=$(cat /etc/motd_hostname.conf)
else
    SERVER_NAME=$(hostname)
fi

# Get server IP
SERVER_IP=$(hostname -I | awk '{print $1}')

# Get client IP (SSH only)
if [[ -n "$SSH_CONNECTION" ]]; then
    CLIENT_IP=$(echo $SSH_CONNECTION | awk '{print $1}')
else
    CLIENT_IP="local/unknown"
fi

echo "=============================================="
echo "🖥️  Welcome to $SERVER_NAME ($SERVER_IP)"
echo "🔑  Logged in from: $CLIENT_IP"
echo "----------------------------------------------"

# Show update status (Debian/Ubuntu)
if command -v apt &>/dev/null; then
    UPDATES=$(apt list --upgradeable 2>/dev/null | grep -v "Listing..." | wc -l)
    if [ "$UPDATES" -gt 0 ]; then
        echo "📦 $UPDATES package(s) can be updated."
    else
        echo "✅ System is up to date."
    fi
fi

echo "=============================================="
echo
EOF

chmod +x "$MOTD_SCRIPT"
log "MOTD script created at $MOTD_SCRIPT"

log "===================================================="
log "==== Setup complete. System is ready!           ===="
log "===================================================="