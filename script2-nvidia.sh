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
# REBOOT when complete.
# =============================================================

# === VERIFY CACHYOS KERNEL IS RUNNING ===
if ! uname -r | grep -q "cachy"; then
    echo "ERROR: Not running on the CachyOS kernel!"
    echo "Current kernel: $(uname -r)"
    echo "Please reboot and select the CachyOS kernel from GRUB."
    exit 1
fi
echo "CachyOS kernel confirmed: $(uname -r)"

# === NVIDIA DEPENDENCIES ===
sudo dnf install -y kernel-devel kernel-headers gcc make dkms acpid \
  libglvnd-glx libglvnd-opengl libglvnd-devel pkgconfig libxcb egl-wayland

# === DOWNLOAD NVIDIA DRIVER ===
cd ~/Downloads
wget https://us.download.nvidia.com/XFree86/Linux-x86_64/595.71.05/NVIDIA-Linux-x86_64-595.71.05.run
chmod +x NVIDIA-Linux-x86_64-595.71.05.run

echo ""
echo "========================================================"
echo " SCRIPT 2 COMPLETE"
echo ""
echo " When prompted by the NVIDIA installer:"
echo "   - Select NO to the xconfig utility"
echo ""
echo " NOTE: If you have not yet enabled GPU passthrough in"
echo " Proxmox, do so before running script3-sunshine.sh."
echo " Sunshine requires the GPU to be active."
echo "========================================================"
echo ""
read -p "Press Enter to launch the NVIDIA installer..."
sudo ~/Downloads/NVIDIA-Linux-x86_64-595.71.05.run
echo ""
echo "NVIDIA installer complete. Please reboot and run script3-sunshine.sh"
