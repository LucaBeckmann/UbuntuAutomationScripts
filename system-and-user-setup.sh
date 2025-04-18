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
log "==== Step 1: Set timezone to Europe/Berlin     ===="
log "===================================================="
timedatectl set-timezone Europe/Berlin
log "Timezone set to Europe/Berlin."

log "===================================================="
log "==== Step 2: Start user interaction            ===="
log "===================================================="

# Ask for username
read -rp "Enter desired username: " USERNAME
log "Username to create: $USERNAME"

# Ask for password twice and compare
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

# Ask for GitHub username
read -rp "GitHub username to fetch SSH keys from: " GITHUB_USER
log "GitHub user for SSH keys: $GITHUB_USER"

log "===================================================="
log "==== Step 3: Create user $USERNAME              ===="
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
log "==== Step 4: Setup SSH directory & import key   ===="
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
log "==== Step 5: Harden SSH configuration           ===="
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

for file in "$conf_dir"/*.conf 2>/dev/null; do
    if grep -q "^PasswordAuthentication" "$file"; then
        sed -i 's/^PasswordAuthentication.*/PasswordAuthentication no/' "$file"
        log "PasswordAuthentication disabled in $file"
        conf_updated=true
    fi
done

if [ "$conf_updated" = false ]; then
    echo -e "# Disable password authentication\nPasswordAuthentication no" > "$conf_dir/10-disable-password.conf"
    log "Created $conf_dir/10-disable-password.conf to disable password login."
fi

systemctl restart ssh
log "SSH service restarted. Only key login is now enabled."

log "===================================================="
log "==== All steps completed. System is ready!      ===="
log "===================================================="
