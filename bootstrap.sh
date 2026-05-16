#!/bin/bash
# ================================================================
# bootstrap.sh - First Login Setup
# ================================================================
# Runs automatically on first SSH login as the 'setup' user.
# Creates your real user account, removes the setup user,
# and kicks off the main setup script chain.
# ================================================================

REPO_PATH="/opt/fedora_to_cachyos"

echo ""
echo "========================================================"
echo " Fedora Gaming VM - First Boot Setup"
echo "========================================================"
echo ""
echo " This will create your user account and begin the"
echo " automated setup process."
echo ""

# === GET USERNAME ===
while true; do
    read -p "Enter your desired username: " NEW_USER
    if [ -z "$NEW_USER" ]; then
        echo "Username cannot be empty."
        continue
    fi
    if echo "$NEW_USER" | grep -qP '[^a-z0-9_-]'; then
        echo "Username can only contain lowercase letters, numbers, - and _"
        continue
    fi
    if id "$NEW_USER" &>/dev/null; then
        echo "User '$NEW_USER' already exists. Choose another."
        continue
    fi
    break
done

# === GET PASSWORD ===
while true; do
    read -s -p "Enter password for ${NEW_USER}: " NEW_PASS
    echo ""
    read -s -p "Confirm password: " NEW_PASS2
    echo ""
    if [ "$NEW_PASS" != "$NEW_PASS2" ]; then
        echo "Passwords do not match. Try again."
        continue
    fi
    if [ -z "$NEW_PASS" ]; then
        echo "Password cannot be empty."
        continue
    fi
    break
done

# === GET HOSTNAME ===
read -p "Enter hostname for this VM (default: gamingvm): " NEW_HOST
NEW_HOST=${NEW_HOST:-gamingvm}

echo ""
echo "Creating user '${NEW_USER}'..."

# === CREATE USER WITH CORRECT GROUPS ===
sudo useradd -m -G wheel,video,render,input,seat "$NEW_USER"
echo "${NEW_USER}:${NEW_PASS}" | sudo chpasswd

# === SET HOSTNAME ===
sudo hostnamectl set-hostname "$NEW_HOST"

# === MOVE REPO TO NEW USER'S HOME ===
sudo cp -r "$REPO_PATH" "/home/${NEW_USER}/fedora_to_cachyos"
sudo chown -R "${NEW_USER}:${NEW_USER}" "/home/${NEW_USER}/fedora_to_cachyos"
sudo chmod +x "/home/${NEW_USER}/fedora_to_cachyos"/*.sh

# === ADD SUDOERS ENTRY ===
# Ensure wheel group has sudo access
sudo grep -q "^%wheel" /etc/sudoers || \
    echo "%wheel ALL=(ALL) ALL" | sudo tee -a /etc/sudoers

# === REMOVE BOOTSTRAP FROM SETUP USER PROFILE ===
# Prevent it running again if setup user logs in
sudo rm -f /home/setup/.bash_profile

echo ""
echo "========================================================"
echo " User '${NEW_USER}' created successfully!"
echo ""
echo " Setup repo is at: ~/fedora_to_cachyos"
echo ""
echo " Starting script1-base.sh as ${NEW_USER}..."
echo " You will be switched to the new user automatically."
echo "========================================================"
echo ""

# === REMOVE SETUP USER AFTER SWITCHING ===
# Schedule setup user removal after we switch away from it
sudo bash -c "sleep 5 && userdel -r setup 2>/dev/null" &

# === HAND OFF TO SCRIPT 1 AS NEW USER ===
# Switch to the new user and run script 1
exec sudo -u "$NEW_USER" -i bash -c "
    cd ~/fedora_to_cachyos
    echo ''
    echo 'Logged in as ${NEW_USER}. Starting script 1...'
    echo ''
    bash script1-base.sh
"
