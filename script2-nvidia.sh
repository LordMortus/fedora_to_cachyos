#!/bin/bash
set -e

# === ROOT CHECK ===
if [ "$EUID" -eq 0 ]; then
    echo "ERROR: Do not run this script as root!"
    echo "Run as your normal user account with sudo available."
    exit 1
fi

# =============================================================
# SCRIPT 2 OF 4 - NVIDIA Driver
# Run this on the CachyOS kernel AFTER rebooting from script 1.
# Verify you are on the correct kernel before continuing:
#   uname -r   (should show cachyos in the version string)
#
# IMPORTANT: Enable GPU passthrough in Proxmox BEFORE running
# this script. The NVIDIA installer needs to detect the GPU
# to offer the open kernel module option and initramfs rebuild.
#
# When the NVIDIA installer runs:
#   - Choose the Open/MIT kernel module when offered
#   - Select NO to the xconfig utility
#   - Select YES to rebuilding initramfs at the end
#
# REBOOT when complete.
# =============================================================

# === VERIFY CACHYOS KERNEL IS RUNNING ===
if ! uname -r | grep -q "cachy"; then
    echo "ERROR: Not running on the CachyOS kernel!"
    echo "Current kernel: $(uname -r)"
    echo "Please reboot - the CachyOS kernel should boot automatically."
    exit 1
fi
echo "CachyOS kernel confirmed: $(uname -r)"

# === INSTALL WGET IF MISSING ===
# Minimal Fedora installs may not include wget
if ! command -v wget &>/dev/null; then
    echo "Installing wget..."
    sudo dnf install -y wget
fi

# === NVIDIA DEPENDENCIES ===
sudo dnf install -y kernel-devel kernel-headers gcc make dkms acpid \
  libglvnd-glx libglvnd-opengl libglvnd-devel pkgconfig libxcb egl-wayland

# === DOWNLOAD NVIDIA DRIVER ===
mkdir -p ~/Downloads
cd ~/Downloads
wget https://us.download.nvidia.com/XFree86/Linux-x86_64/595.71.05/NVIDIA-Linux-x86_64-595.71.05.run
chmod +x NVIDIA-Linux-x86_64-595.71.05.run

echo ""
echo "========================================================"
echo " NVIDIA installer is about to launch."
echo ""
echo " When prompted:"
echo "   - Choose the Open/MIT kernel module when offered"
echo "   - Select NO to the xconfig utility"
echo "   - Select YES to rebuilding initramfs at the end"
echo "========================================================"
echo ""
read -p "Press Enter to launch the NVIDIA installer..."
sudo ~/Downloads/NVIDIA-Linux-x86_64-595.71.05.run

# === INCLUDE NVIDIA GSP FIRMWARE IN INITRAMFS ===
# Required for the open kernel module on Turing+ GPUs (RTX 2060 etc).
# Without this, nvidia_drm fails to create /dev/dri/card0 at boot,
# which prevents Wayland compositors from using the GPU.
echo ""
echo "Configuring NVIDIA GSP firmware for initramfs..."
NVIDIA_FW_VER=$(ls /lib/firmware/nvidia/ | grep -E '^[0-9]' | head -1)
if [ -n "$NVIDIA_FW_VER" ]; then
    echo "install_items+=\" /lib/firmware/nvidia/${NVIDIA_FW_VER}/gsp_tu10x.bin /lib/firmware/nvidia/${NVIDIA_FW_VER}/gsp_ga10x.bin \"" | \
        sudo tee /etc/dracut.conf.d/nvidia-firmware.conf
    echo "GSP firmware dracut config written for version ${NVIDIA_FW_VER}"
    sudo dracut -f
    echo "Initramfs rebuilt with NVIDIA firmware included."
else
    echo "WARNING: Could not detect NVIDIA firmware version."
    echo "If /dev/dri/card0 is missing after reboot, run:"
    echo "  echo 'options nvidia NVreg_EnableGpuFirmware=0' | sudo tee /etc/modprobe.d/nvidia-gsp.conf"
    echo "  sudo dracut -f"
fi

echo ""
echo "========================================================"
echo " SCRIPT 2 COMPLETE"
echo ""
echo " NEXT STEP: Reboot then run script3-sunshine.sh"
echo "========================================================"
