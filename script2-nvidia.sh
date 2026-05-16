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
# 64-bit build deps and GL dispatch layer
sudo dnf install -y kernel-devel kernel-headers gcc make dkms acpid \
  libglvnd-glx libglvnd-opengl libglvnd-devel pkgconfig libxcb egl-wayland

# 32-bit GL dispatch layer — required for Steam and 32-bit games
# These let Steam's 32-bit runtime find the NVIDIA GL libraries correctly
sudo dnf install -y \
  libglvnd-glx.i686 \
  libglvnd-opengl.i686 \
  libglvnd-egl.i686 \
  libglvnd-gles.i686 \
  glibc.i686 \
  libstdc++.i686

# === DOWNLOAD NVIDIA DRIVER ===
mkdir -p ~/Downloads
cd ~/Downloads
NVIDIA_RUN="NVIDIA-Linux-x86_64-595.71.05.run"
if [ ! -f "$NVIDIA_RUN" ]; then
    wget https://us.download.nvidia.com/XFree86/Linux-x86_64/595.71.05/${NVIDIA_RUN}
fi
chmod +x "$NVIDIA_RUN"

# === BLACKLIST NOUVEAU (required before silent install) ===
# The installer does this itself in interactive mode; in silent mode
# we pre-create the file so it doesn't trip over missing dracut triggers.
if ! grep -q "blacklist nouveau" /etc/modprobe.d/blacklist-nouveau.conf 2>/dev/null; then
    echo "blacklist nouveau" | sudo tee /etc/modprobe.d/blacklist-nouveau.conf
    echo "options nouveau modeset=0" | sudo tee -a /etc/modprobe.d/blacklist-nouveau.conf
fi

# === RUN NVIDIA INSTALLER ===
# Detect if we have a display / interactive session available.
# If running headless (no $DISPLAY and no $WAYLAND_DISPLAY and no TTY input),
# use fully silent mode. Otherwise offer the choice.
if [ -t 0 ] && { [ -n "$DISPLAY" ] || [ -n "$WAYLAND_DISPLAY" ]; }; then
    # Interactive session with display — offer choice
    echo ""
    echo "========================================================"
    echo " NVIDIA Installer"
    echo " Running with display available."
    echo " Choose install mode:"
    echo "   1) Silent (recommended - no prompts)"
    echo "   2) Interactive (manual - legacy fallback)"
    echo "========================================================"
    read -p "Choice [1/2, default 1]: " INSTALL_MODE
    INSTALL_MODE=${INSTALL_MODE:-1}
else
    # Headless or non-interactive — force silent
    INSTALL_MODE=1
fi

if [ "$INSTALL_MODE" = "2" ]; then
    echo "Launching interactive installer..."
    echo "When prompted: select NO to the xconfig utility."
    sudo ~/Downloads/${NVIDIA_RUN}
else
    echo "Running silent NVIDIA install..."
    # --silent                : no UI/prompts
    # --accept-license        : accept EULA
    # --no-x-check            : skip X server running check (headless)
    # --no-nouveau-check      : we already blacklisted it above
    # --dkms                  : register with DKMS for kernel update survival
    # --install-compat32-libs : install 32-bit GL libs (required for Steam)
    # Default: does NOT run nvidia-xconfig (correct for Wayland)
    sudo ~/Downloads/${NVIDIA_RUN} \
        --silent \
        --accept-license \
        --no-x-check \
        --no-nouveau-check \
        --dkms \
        --install-compat32-libs \
        2>&1 | tee ~/nvidia-install.log

    # Verify the install actually worked
    if ! /usr/bin/nvidia-smi &>/dev/null; then
        echo ""
        echo "ERROR: nvidia-smi failed after install."
        echo "Check the log: cat ~/nvidia-install.log"
        echo "You may need to reboot first, then verify:"
        echo "  nvidia-smi"
        exit 1
    fi
    echo "NVIDIA driver installed and verified."
fi

echo ""
echo "========================================================"
echo " SCRIPT 2 COMPLETE"
echo ""
echo " NVIDIA driver installed."
echo " Install log: ~/nvidia-install.log"
echo ""
echo " NOTE: Ensure GPU passthrough is active in Proxmox"
echo " before running script3-sunshine.sh."
echo "========================================================"
echo ""
echo "NVIDIA installer complete. Please reboot and run script3-sunshine.sh"
