#!/bin/bash

echo "=== Create a System User for Docker Compose ==="
read -p "Please enter the desired username: " USERNAME

# Step 1: Create system user (no home, valid shell for command execution)
echo "[1/4] Creating system user '$USERNAME'..."
sudo useradd -r -M -s /bin/bash "$USERNAME"

# Step 2: Lock login access (so user cannot log in interactively)
echo "[2/4] Locking login for user '$USERNAME'..."
sudo passwd -l "$USERNAME" >/dev/null 2>&1

# Step 3: Add user to docker group
echo "[3/4] Adding '$USERNAME' to the 'docker' group..."
sudo usermod -aG docker "$USERNAME"

# Step 4: Create the service directory under /opt/docker/<username>
DIR="/opt/docker/$USERNAME"
echo "[4/4] Creating service directory '$DIR'..."
sudo mkdir -p "$DIR"

echo "Setting ownership to $USERNAME:docker..."
sudo chown -R "$USERNAME":docker "$DIR"

echo
echo "Done!"
echo "User:        $USERNAME"
echo "Directory:   $DIR"
echo "Owner:       $USERNAME:docker"
echo "==============================================="
echo "The user is now ready to run docker-compose services."
