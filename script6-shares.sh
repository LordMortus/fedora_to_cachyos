#!/bin/bash
set -e

# === ROOT CHECK ===
if [ "$EUID" -eq 0 ]; then
    echo "ERROR: Do not run this script as root!"
    echo "Run as your normal user account with sudo available."
    exit 1
fi

# =============================================================
# SCRIPT 6 - NFS and Samba Network Share Mounter
# Sets up permanent mounts via fstab (mount on boot)
# Run this after the system is fully configured.
# =============================================================

echo "========================================================"
echo " Network Share Setup"
echo " This script will configure NFS and/or Samba shares"
echo " to mount automatically on boot via /etc/fstab"
echo "========================================================"
echo ""

# === INSTALL DEPENDENCIES ===
echo "Installing NFS and Samba client packages..."
sudo dnf install -y nfs-utils cifs-utils

# === HELPER FUNCTIONS ===

add_nfs_share() {
    echo ""
    echo "--- NFS Share Configuration ---"
    read -p "Server IP or hostname: " NFS_SERVER
    read -p "Share path on server (e.g. /mnt/data): " NFS_SHARE
    read -p "Local mount point (e.g. /mnt/nfs/data): " NFS_MOUNT

    # Create mount point
    sudo mkdir -p "$NFS_MOUNT"

    # Add to fstab
    echo "${NFS_SERVER}:${NFS_SHARE}  ${NFS_MOUNT}  nfs  defaults,_netdev,auto  0  0" | sudo tee -a /etc/fstab

    echo "NFS share added: ${NFS_SERVER}:${NFS_SHARE} -> ${NFS_MOUNT}"
}

add_samba_share() {
    echo ""
    echo "--- Samba Share Configuration ---"
    read -p "Server IP or hostname: " SMB_SERVER
    read -p "Share name on server (e.g. data): " SMB_SHARE
    read -p "Local mount point (e.g. /mnt/smb/data): " SMB_MOUNT
    read -p "Samba username: " SMB_USER
    read -s -p "Samba password: " SMB_PASS
    echo ""

    # Create mount point
    sudo mkdir -p "$SMB_MOUNT"

    # Store credentials securely in a file rather than fstab
    CRED_FILE="/etc/samba/credentials-$(echo $SMB_MOUNT | tr '/' '-')"
    sudo mkdir -p /etc/samba
    sudo tee "$CRED_FILE" > /dev/null << EOF
username=${SMB_USER}
password=${SMB_PASS}
EOF
    sudo chmod 600 "$CRED_FILE"

    # Add to fstab using credentials file
    echo "//${SMB_SERVER}/${SMB_SHARE}  ${SMB_MOUNT}  cifs  credentials=${CRED_FILE},_netdev,auto,uid=$(id -u),gid=$(id -g)  0  0" | sudo tee -a /etc/fstab

    echo "Samba share added: //${SMB_SERVER}/${SMB_SHARE} -> ${SMB_MOUNT}"
    echo "Credentials stored securely in: ${CRED_FILE}"
}

# === NFS SHARES ===
echo "How many NFS shares do you want to add?"
read -p "Number of NFS shares (0 to skip): " NFS_COUNT

for ((i=1; i<=NFS_COUNT; i++)); do
    echo ""
    echo "NFS Share $i of $NFS_COUNT"
    add_nfs_share
done

# === SAMBA SHARES ===
echo ""
echo "How many Samba shares do you want to add?"
read -p "Number of Samba shares (0 to skip): " SMB_COUNT

for ((i=1; i<=SMB_COUNT; i++)); do
    echo ""
    echo "Samba Share $i of $SMB_COUNT"
    add_samba_share
done

# === ENABLE NFS CLIENT SERVICE ===
if [ "$NFS_COUNT" -gt 0 ]; then
    sudo systemctl enable --now nfs-client.target
fi

# === TEST MOUNTS ===
echo ""
echo "Testing all new mounts..."
sudo mount -a && echo "All shares mounted successfully!" || echo "WARNING: One or more mounts failed. Check /etc/fstab entries."

echo ""
echo "========================================================"
echo " SCRIPT 6 COMPLETE"
echo ""
echo " Shares configured:"
echo "  - NFS shares: $NFS_COUNT"
echo "  - Samba shares: $SMB_COUNT"
echo ""
echo " All shares will mount automatically on boot."
echo " To manually remount all shares at any time:"
echo "   sudo mount -a"
echo ""
echo " To check currently mounted shares:"
echo "   df -h | grep -E 'nfs|cifs'"
echo ""
echo " To view fstab entries added by this script:"
echo "   grep -E 'nfs|cifs' /etc/fstab"
echo "========================================================"
