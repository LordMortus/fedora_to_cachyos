#!/bin/bash
set -e

# =============================================================
# SCRIPT 8 - iSCSI Connection (Existing Data)
# Connects to a single iSCSI target that already has data
# and mounts it permanently via fstab.
# NO formatting - existing data is preserved.
# =============================================================

echo "========================================================"
echo " iSCSI Setup - Existing Data"
echo " This script will connect to an iSCSI target and mount"
echo " it permanently. No formatting will be performed."
echo " Existing data on the disk will be preserved."
echo "========================================================"
echo ""

# === INSTALL DEPENDENCIES ===
echo "Installing iSCSI initiator packages..."
sudo dnf install -y iscsi-initiator-utils

# === ENABLE ISCSID SERVICE ===
sudo systemctl enable --now iscsid

# === GATHER INFO ===
read -p "iSCSI target portal IP or hostname: " ISCSI_PORTAL
read -p "iSCSI target port (default 3260): " ISCSI_PORT
ISCSI_PORT=${ISCSI_PORT:-3260}

# === DISCOVER TARGETS ===
echo ""
echo "Discovering iSCSI targets on ${ISCSI_PORTAL}:${ISCSI_PORT}..."
sudo iscsiadm -m discovery -t sendtargets -p "${ISCSI_PORTAL}:${ISCSI_PORT}"

echo ""
echo "Available targets shown above."
read -p "Enter the full target IQN to connect to: " ISCSI_IQN

# === CONNECT TO TARGET ===
echo ""
echo "Connecting to target ${ISCSI_IQN}..."
sudo iscsiadm -m node \
    --targetname "${ISCSI_IQN}" \
    --portal "${ISCSI_PORTAL}:${ISCSI_PORT}" \
    --login

# === WAIT FOR DEVICE TO APPEAR ===
echo "Waiting for block device to appear..."
sleep 3

# === IDENTIFY THE DISK ===
echo ""
echo "Available block devices:"
lsblk
echo ""
read -p "Enter the device name for the iSCSI disk (e.g. sdb, sdc): " ISCSI_DEV
ISCSI_DEVICE="/dev/${ISCSI_DEV}"

# === DETECT EXISTING FILESYSTEM ===
echo ""
echo "Detecting existing filesystem on ${ISCSI_DEVICE}..."
EXISTING_FS=$(sudo blkid -s TYPE -o value "${ISCSI_DEVICE}" 2>/dev/null || echo "unknown")
echo "Detected filesystem: ${EXISTING_FS}"

if [ "$EXISTING_FS" = "unknown" ]; then
    echo ""
    echo "WARNING: No filesystem detected on ${ISCSI_DEVICE}."
    echo "The disk may be unformatted or use an unsupported filesystem."
    read -p "Continue anyway? (yes/no): " CONTINUE_CONFIRM
    if [ "$CONTINUE_CONFIRM" != "yes" ]; then
        echo "Aborting. Use script7-iscsi.sh to format and mount a new disk."
        exit 1
    fi
fi

# === MOUNT POINT ===
echo ""
read -p "Local mount point (e.g. /mnt/iscsi): " ISCSI_MOUNT
sudo mkdir -p "${ISCSI_MOUNT}"

# === GET UUID FOR FSTAB ===
ISCSI_UUID=$(sudo blkid -s UUID -o value "${ISCSI_DEVICE}")
echo "Disk UUID: ${ISCSI_UUID}"

# === ADD TO FSTAB ===
echo "UUID=${ISCSI_UUID}  ${ISCSI_MOUNT}  ${EXISTING_FS:-ext4}  defaults,_netdev,auto  0  0" | sudo tee -a /etc/fstab

# === CONFIGURE ISCSI TO RECONNECT ON BOOT ===
sudo iscsiadm -m node \
    --targetname "${ISCSI_IQN}" \
    --portal "${ISCSI_PORTAL}:${ISCSI_PORT}" \
    --op update \
    --name node.startup \
    --value automatic

# === ENABLE ISCSI SERVICES FOR BOOT ===
sudo systemctl enable iscsid
sudo systemctl enable iscsi

# === MOUNT NOW ===
echo ""
echo "Mounting ${ISCSI_DEVICE} at ${ISCSI_MOUNT}..."
sudo mount -a && echo "Mount successful!" || echo "WARNING: Mount failed. Check /etc/fstab entry."

# === VERIFY ===
echo ""
echo "Verifying mount:"
df -h | grep "${ISCSI_MOUNT}" || echo "WARNING: Mount point not found in df output."

echo ""
echo "========================================================"
echo " SCRIPT 8 COMPLETE"
echo ""
echo " iSCSI Configuration Summary:"
echo "  Portal:      ${ISCSI_PORTAL}:${ISCSI_PORT}"
echo "  Target IQN:  ${ISCSI_IQN}"
echo "  Device:      ${ISCSI_DEVICE}"
echo "  Filesystem:  ${EXISTING_FS}"
echo "  UUID:        ${ISCSI_UUID}"
echo "  Mount point: ${ISCSI_MOUNT}"
echo ""
echo " The iSCSI target will reconnect and mount automatically"
echo " on every boot."
echo ""
echo " Useful commands:"
echo "  Check connection:  sudo iscsiadm -m session"
echo "  Check mount:       df -h | grep iscsi"
echo "  Manual reconnect:  sudo iscsiadm -m node --loginall=automatic"
echo "========================================================"
