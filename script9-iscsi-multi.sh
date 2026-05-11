#!/bin/bash
set -e

# === ROOT CHECK ===
if [ "$EUID" -eq 0 ]; then
    echo "ERROR: Do not run this script as root!"
    echo "Run as your normal user account with sudo available."
    exit 1
fi

# =============================================================
# SCRIPT 9 - Multiple iSCSI Connections
# Connects to multiple dedicated iSCSI targets, each belonging
# exclusively to this VM. Optionally formats new disks.
# Configures all connections to persist across reboots.
# =============================================================

echo "========================================================"
echo " Multiple iSCSI Setup"
echo " This script will connect to multiple iSCSI targets."
echo " Each disk is dedicated to this VM (not shared)."
echo " You can mix new disks (format) and existing data."
echo "========================================================"
echo ""

# === INSTALL DEPENDENCIES ===
echo "Installing iSCSI initiator packages..."
sudo dnf install -y iscsi-initiator-utils

# === ENABLE ISCSID SERVICE ===
sudo systemctl enable --now iscsid

# === HOW MANY ===
read -p "How many iSCSI targets do you want to connect to? " TARGET_COUNT

# === LOOP THROUGH EACH TARGET ===
for ((i=1; i<=TARGET_COUNT; i++)); do
    echo ""
    echo "========================================================"
    echo " Target $i of $TARGET_COUNT"
    echo "========================================================"

    # --- Portal ---
    read -p "Portal IP or hostname: " ISCSI_PORTAL
    read -p "Portal port (default 3260): " ISCSI_PORT
    ISCSI_PORT=${ISCSI_PORT:-3260}

    # --- Discover ---
    echo ""
    echo "Discovering targets on ${ISCSI_PORTAL}:${ISCSI_PORT}..."
    sudo iscsiadm -m discovery -t sendtargets -p "${ISCSI_PORTAL}:${ISCSI_PORT}"

    echo ""
    read -p "Enter the full target IQN to connect to: " ISCSI_IQN

    # --- Connect ---
    echo "Connecting to ${ISCSI_IQN}..."
    sudo iscsiadm -m node \
        --targetname "${ISCSI_IQN}" \
        --portal "${ISCSI_PORTAL}:${ISCSI_PORT}" \
        --login

    # --- Wait for device ---
    echo "Waiting for block device to appear..."
    sleep 3

    # --- Identify disk ---
    echo ""
    echo "Available block devices:"
    lsblk
    echo ""
    read -p "Enter the device name for this iSCSI disk (e.g. sdb, sdc): " ISCSI_DEV
    ISCSI_DEVICE="/dev/${ISCSI_DEV}"

    # --- New or existing data ---
    echo ""
    read -p "Does this disk have existing data? (yes/no): " HAS_DATA

    if [ "$HAS_DATA" = "no" ]; then
        # Format new disk
        read -p "Format ${ISCSI_DEVICE} as ext4? This will ERASE all data! (yes/no): " FORMAT_CONFIRM
        if [ "$FORMAT_CONFIRM" = "yes" ]; then
            echo "Formatting ${ISCSI_DEVICE} as ext4..."
            sudo mkfs.ext4 -L "iscsi-disk-${i}" "${ISCSI_DEVICE}"
            echo "Format complete."
            EXISTING_FS="ext4"
        else
            echo "Skipping format."
            EXISTING_FS=$(sudo blkid -s TYPE -o value "${ISCSI_DEVICE}" 2>/dev/null || echo "ext4")
        fi
    else
        # Detect existing filesystem
        EXISTING_FS=$(sudo blkid -s TYPE -o value "${ISCSI_DEVICE}" 2>/dev/null || echo "ext4")
        echo "Detected filesystem: ${EXISTING_FS}"
    fi

    # --- Mount point ---
    echo ""
    read -p "Local mount point (e.g. /mnt/iscsi-${i}): " ISCSI_MOUNT
    sudo mkdir -p "${ISCSI_MOUNT}"

    # --- Get UUID ---
    ISCSI_UUID=$(sudo blkid -s UUID -o value "${ISCSI_DEVICE}")
    echo "Disk UUID: ${ISCSI_UUID}"

    # --- Add to fstab ---
    echo "UUID=${ISCSI_UUID}  ${ISCSI_MOUNT}  ${EXISTING_FS}  defaults,_netdev,auto  0  0" | sudo tee -a /etc/fstab

    # --- Configure auto reconnect ---
    sudo iscsiadm -m node \
        --targetname "${ISCSI_IQN}" \
        --portal "${ISCSI_PORTAL}:${ISCSI_PORT}" \
        --op update \
        --name node.startup \
        --value automatic

    echo ""
    echo "Target $i configured successfully."
    echo "  Device:      ${ISCSI_DEVICE}"
    echo "  Filesystem:  ${EXISTING_FS}"
    echo "  UUID:        ${ISCSI_UUID}"
    echo "  Mount point: ${ISCSI_MOUNT}"
done

# === ENABLE ISCSI SERVICES FOR BOOT ===
sudo systemctl enable iscsid
sudo systemctl enable iscsi

# === MOUNT ALL ===
echo ""
echo "Mounting all configured shares..."
sudo mount -a && echo "All shares mounted successfully!" || echo "WARNING: One or more mounts failed. Check /etc/fstab."

# === VERIFY ===
echo ""
echo "Currently mounted iSCSI volumes:"
df -h | grep -E "iscsi|sd[b-z]" || echo "No iSCSI mounts found in df output."

echo ""
echo "Active iSCSI sessions:"
sudo iscsiadm -m session || echo "No active sessions found."

echo ""
echo "========================================================"
echo " SCRIPT 9 COMPLETE"
echo ""
echo " $TARGET_COUNT iSCSI target(s) configured."
echo " All will reconnect and mount automatically on boot."
echo ""
echo " Useful commands:"
echo "  List sessions:     sudo iscsiadm -m session"
echo "  Check mounts:      df -h"
echo "  View fstab:        grep UUID /etc/fstab"
echo "  Manual reconnect:  sudo iscsiadm -m node --loginall=automatic"
echo "  Manual mount all:  sudo mount -a"
echo "========================================================"
