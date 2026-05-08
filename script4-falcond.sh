#!/bin/bash
set -e

# =============================================================
# SCRIPT 4 OF 4 - falcond Performance Daemon
# Run this on the CachyOS kernel AFTER rebooting from script 3.
# This is the final script - no reboot required after this one.
# =============================================================

# === VERIFY CACHYOS KERNEL IS RUNNING ===
if ! uname -r | grep -q "cachy"; then
    echo "ERROR: Not running on the CachyOS kernel!"
    echo "Current kernel: $(uname -r)"
    echo "Please reboot and select the CachyOS kernel from GRUB."
    exit 1
fi
echo "CachyOS kernel confirmed: $(uname -r)"
KERNEL_PKG=$(cat ~/.cachyos-install-variant 2>/dev/null || echo "unknown")
echo "Kernel variant: $KERNEL_PKG"

# === DEPENDENCIES ===
sudo dnf install -y zig git

# === CLONE AND BUILD FALCOND ===
cd ~/Downloads
git clone https://git.pika-os.com/general-packages/falcond.git
cd falcond/falcond

# Build optimized release binary
zig build -Doptimize=ReleaseFast

# Install binary and systemd service
sudo install -Dm755 zig-out/bin/falcond /usr/bin/falcond
sudo install -Dm644 debian/falcond.service /etc/systemd/system/falcond.service

# === INSTALL PROFILES ===
cd ~/Downloads
git clone https://github.com/PikaOS-Linux/falcond-profiles.git
sudo mkdir -p /usr/share/falcond/profiles
sudo cp -r falcond-profiles/profiles/* /usr/share/falcond/profiles/
sudo cp falcond-profiles/system.conf /usr/share/falcond/system.conf

# === ENABLE AND START ===
sudo systemctl daemon-reload
sudo systemctl enable --now falcond
sudo systemctl status falcond --no-pager

echo ""
echo "========================================================"
echo " SCRIPT 4 COMPLETE - Setup finished!"
echo ""
echo " falcond is installed and running."
echo " Config auto-generated at /etc/falcond/config.conf"
echo " Check status: sudo systemctl status falcond"
echo ""
echo " Your system is ready for game streaming."
echo " Connect via Moonlight to: https://localhost:47990"
echo ""
echo " OPTIONAL: Install the falcond GUI"
echo "   sudo dnf install -y libadwaita-devel lua-devel meson ninja-build"
echo "   cd ~/Downloads"
echo "   git clone https://git.pika-os.com/custom-gui-packages/falcond-gui.git"
echo "   cd falcond-gui"
echo "   meson setup build"
echo "   ninja -C build"
echo "   sudo ninja -C build install"
echo "========================================================"
