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
echo "Setting up system..."

# === INSTALL SEATD SO SEAT GROUP EXISTS ===
# seatd is required by niri - install it now so the seat group
# exists when we create the user
sudo dnf install -y seatd 2>/dev/null || true
sudo groupadd seat 2>/dev/null || true

# === CREATE USER WITH CORRECT GROUPS ===
echo "Creating user '${NEW_USER}'..."
sudo useradd -m -G wheel,video,render,input,seat "$NEW_USER"
echo "${NEW_USER}:${NEW_PASS}" | sudo chpasswd

# === SET HOSTNAME ===
sudo hostnamectl set-hostname "$NEW_HOST"

# === COPY REPO TO NEW USER'S HOME ===
sudo cp -r "$REPO_PATH" "/home/${NEW_USER}/fedora_to_cachyos"
sudo chown -R "${NEW_USER}:${NEW_USER}" "/home/${NEW_USER}/fedora_to_cachyos"
sudo find "/home/${NEW_USER}/fedora_to_cachyos" -name "*.sh" -exec chmod +x {} \;

# === ENSURE SUDOERS IS CONFIGURED ===
sudo grep -q "^%wheel" /etc/sudoers || \
    echo "%wheel ALL=(ALL) ALL" | sudo tee -a /etc/sudoers

# === REMOVE BOOTSTRAP FROM SETUP USER PROFILE ===
sudo rm -f /home/setup/.bash_profile

echo ""
echo "========================================================"
echo " User '${NEW_USER}' created successfully!"
echo " Hostname set to: ${NEW_HOST}"
echo ""
echo " Switching to ${NEW_USER} and starting script 1..."
echo "========================================================"
echo ""

# === SCHEDULE SETUP USER REMOVAL ===
sudo bash -c "sleep 10 && userdel -r setup 2>/dev/null" &

# === SWITCH TO NEW USER AND RUN SCRIPT 1 ===
sudo su - "$NEW_USER" -c "cd ~/fedora_to_cachyos && bash script-niri.sh"
