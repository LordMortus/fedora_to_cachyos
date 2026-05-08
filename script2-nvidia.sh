#!/bin/bash
set -e

# =============================================================
# SCRIPT 2 OF 4 - NVIDIA Driver
# Run this on the CachyOS kernel AFTER rebooting from script 1.
# Verify you are on the correct kernel before continuing:
#   uname -r   (should show cachyos in the version string)
# REBOOT when complete.
# =============================================================

# === VERIFY CACHYOS KERNEL IS RUNNING ===
if ! uname -r | grep -q "cachyos"; then
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
echo " NEXT STEP: Run the NVIDIA installer manually now:"
echo "   sudo ~/Downloads/NVIDIA-Linux-x86_64-595.71.05.run"
echo ""
echo " When prompted:"
echo "   - Select NO to the xconfig utility"
echo ""
echo " After the installer finishes, REBOOT,"
echo " then run script3-sunshine.sh"
echo "========================================================"
