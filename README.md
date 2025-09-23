This Bash script automates the initial setup of a Linux (Ubuntu/Debian) server by configuring the timezone, hostname, creating a new user with sudo rights, and securing SSH access. It also installs a custom login message of the day (MOTD) script showing system information and update status.

Features:
- Timezone configuration (interactive selection, validated against system timezones)
- Hostname setup (stored for later use in the MOTD)
- User creation with password confirmation and sudo privileges
- Automatic SSH key import from a specified GitHub account
- Hardened SSH configuration (password authentication disabled, key-based login enforced, root login restricted)
- Custom MOTD script with server name, IP addresses, and update status

All actions are logged to /var/log/user_setup.log.

Requirements:
- Linux system with systemd and timedatectl
- Root privileges
- Internet access (required for fetching GitHub SSH keys)

Usage:
- Clone or download this repository
- Make the script executable: chmod +x user_and_system_setup.sh
- Run the script as root: sudo ./user_and_system_setup.sh

Notes:
- After completion, password-based SSH login will be disabled. Ensure you provide a valid GitHub username with uploaded SSH keys.
- The script creates a backup of your existing SSH configuration at: /etc/ssh/sshd_config.bak
