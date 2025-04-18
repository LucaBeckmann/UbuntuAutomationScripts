#!/bin/bash

# Sicherstellen, dass das Skript als root ausgeführt wird
if [ "$(id -u)" -ne 0 ]; then
  echo "Dieses Skript muss als root ausgeführt werden."
  exit 1
fi

set -e

echo "===================================================="
echo "==== Schritt 1: Setze Zeitzone auf Europe/Berlin ===="
echo "===================================================="
timedatectl set-timezone Europe/Berlin
echo "Zeitzone wurde gesetzt."

echo "===================================================="
echo "==== Schritt 2: Erstelle Benutzer (falls nötig) ===="
echo "===================================================="

USERNAME="SETUSERNAME"
PASSWORD="SETPASSWORD"

if id "$USERNAME" &>/dev/null; then
    echo "Benutzer $USERNAME existiert bereits."
else
    echo "Erstelle Benutzer $USERNAME..."
    useradd -m -s /bin/bash "$USERNAME"
    echo "$USERNAME:$PASSWORD" | chpasswd
    echo "Benutzer $USERNAME wurde erstellt mit Standardpasswort."
fi

echo "Benutzer $USERNAME zur sudo-Gruppe hinzufügen..."
usermod -aG sudo "$USERNAME"
echo "Benutzer $USERNAME hat jetzt sudo-Rechte."

echo "===================================================="
echo "==== Schritt 3: SSH-Verzeichnis & GitHub-Key Setup ===="
echo "===================================================="

USER_HOME="/home/$USERNAME"
SSH_DIR="$USER_HOME/.ssh"
AUTHORIZED_KEYS="$SSH_DIR/authorized_keys"

mkdir -p "$SSH_DIR"
touch "$AUTHORIZED_KEYS"
chmod 700 "$SSH_DIR"
chmod 600 "$AUTHORIZED_KEYS"
chown -R "$USERNAME:$USERNAME" "$SSH_DIR"
GITHUBUSER="SETUSERNAME"

echo "Lade SSH-Keys von GitHub-Benutzer

curl -s https://github.com/$GITHUBUSER.keys | while read -r key; do
    if grep -Fxq "$key" "$AUTHORIZED_KEYS"; then
        echo "Key bereits vorhanden – wird übersprungen."
    else
        echo "$key" >> "$AUTHORIZED_KEYS"
        echo "Key hinzugefügt."
    fi
done

chown "$USERNAME:$USERNAME" "$AUTHORIZED_KEYS"

echo "===================================================="
echo "==== Schritt 4: SSH-Konfiguration absichern (nur Key-Login) ===="
echo "===================================================="

# Backup der aktuellen SSH-Konfigurationsdatei
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
echo "Backup von sshd_config gespeichert unter /etc/ssh/sshd_config.bak"

# SSH Hauptkonfiguration anpassen
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#\?ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#\?UsePAM.*/UsePAM no/' /etc/ssh/sshd_config
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config

# SSH-Key-Login explizit erlauben
if grep -q "^#\?PubkeyAuthentication" /etc/ssh/sshd_config; then
    sed -i 's/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
else
    echo "PubkeyAuthentication yes" >> /etc/ssh/sshd_config
fi

# SSH-Konfigurationsverzeichnis absichern: alle *.conf-Dateien anpassen
echo "Überprüfe /etc/ssh/sshd_config.d/*.conf auf PasswordAuthentication..."

conf_dir="/etc/ssh/sshd_config.d"
conf_updated=false

for file in "$conf_dir"/*.conf; do
    if grep -q "^PasswordAuthentication" "$file"; then
        sed -i 's/^PasswordAuthentication.*/PasswordAuthentication no/' "$file"
        echo "PasswordAuthentication in $file auf 'no' gesetzt."
        conf_updated=true
    fi
done

# Falls keine Datei existiert oder keine PasswordAuthentication-Zeile vorhanden war
if [ "$conf_updated" = false ]; then
    echo "Erstelle $conf_dir/10-disable-password.conf mit PasswordAuthentication no"
    echo -e "# Deaktiviert Passwortauthentifizierung\nPasswordAuthentication no" > "$conf_dir/10-disable-password.conf"
fi

# SSH neu starten
systemctl restart ssh
echo "SSH-Dienst wurde neu gestartet. Nur Key-Login ist jetzt erlaubt."

echo "===================================================="
echo "==== Alle Schritte abgeschlossen. System bereit! ===="
echo "===================================================="
