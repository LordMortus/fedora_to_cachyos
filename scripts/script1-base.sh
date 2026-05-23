#!/bin/bash
set -e

# === ROOT CHECK ===
if [ "$EUID" -eq 0 ]; then
    echo "ERROR: Do not run this script as root!"
    echo "Run as your normal user account with sudo available."
    exit 1
fi

# =============================================================
# SCRIPT 1 OF 4 - Base Setup & CachyOS Kernel
# Run this first, on the default Fedora kernel.
# REBOOT INTO CACHYOS KERNEL when complete.
# NOTE: If running headless (no display device), the CachyOS
# kernel will be set as the default boot kernel automatically.
# =============================================================

# === CPU ARCHITECTURE CHECK ===
echo "Checking CPU architecture compatibility..."
ARCH_CHECK=$(/lib64/ld-linux-x86-64.so.2 --help | grep "(supported, searched)")

if echo "$ARCH_CHECK" | grep -q "x86-64-v3"; then
    KERNEL_PKG="kernel-cachyos"
    KERNEL_DEVEL_PKG="kernel-cachyos-devel-matched"
    echo "CPU supports x86-64-v3 or higher -- will install kernel-cachyos"
elif echo "$ARCH_CHECK" | grep -q "x86-64-v2"; then
    KERNEL_PKG="kernel-cachyos-lts"
    KERNEL_DEVEL_PKG="kernel-cachyos-lts-devel-matched"
    echo "CPU supports x86-64-v2 only -- will install kernel-cachyos-lts"
else
    echo "ERROR: CPU does not meet minimum x86-64-v2 requirement."
    echo "CachyOS kernel cannot be installed on this hardware."
    exit 1
fi

# === SYSTEM UPDATE ===
sudo dnf upgrade --refresh -y
sudo dnf upgrade -y

# === RPM FUSION ===
sudo dnf install -y \
  https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
  https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

# === COPR TOOLING ===
sudo dnf install -y dnf-plugins-core

# === SELINUX: allow kernel module loading ===
sudo setsebool -P domain_kernel_load_modules on

# === CACHYOS KERNEL ===
echo "y" | sudo dnf copr enable bieszczaders/kernel-cachyos
echo "y" | sudo dnf copr enable bieszczaders/kernel-cachyos-addons

sudo dnf install -y $KERNEL_PKG $KERNEL_DEVEL_PKG
sudo dnf install -y --allowerasing cachyos-settings scx-manager scx-scheds-git scx-tools-git

sudo dnf upgrade --refresh -y
sudo dnf upgrade -y

# === REBUILD INITRAMFS ===
CACHY_VER=$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' $KERNEL_PKG | tail -1)
sudo dracut -f --kver "$CACHY_VER"

# === UPDATE GRUB ===
sudo grub2-mkconfig -o /boot/grub2/grub.cfg

# === SET CACHYOS KERNEL AS DEFAULT ===
# Required for headless systems with no display/GRUB menu access.
# Safe for headed systems too - boots straight to CachyOS kernel.
CACHY_VMLINUZ=$(ls /boot/vmlinuz-*cachy* | tail -1)
if [ -n "$CACHY_VMLINUZ" ]; then
    sudo grubby --set-default "$CACHY_VMLINUZ"
    echo "Default kernel set to: $CACHY_VMLINUZ"
else
    echo "WARNING: Could not find CachyOS kernel in /boot - set default manually"
fi

# === AKONADI FIX ===
# Only applies if KDE PIM is installed.
# Skipped on minimal/headless installs to prevent crashes.
if command -v akonadictl &>/dev/null; then
    if ! rpm -q akonadi-server &>/dev/null; then
        echo "KDE PIM not installed - masking Akonadi to prevent crashes..."
        akonadictl stop 2>/dev/null || true
        rm -rf ~/.local/share/akonadi/
        systemctl --user mask akonadi.service
        systemctl --user mask akonadi.socket
    else
        echo "KDE PIM detected - leaving Akonadi enabled."
    fi
else
    echo "KDE not detected - skipping Akonadi config."
fi

echo ""
echo "========================================================"
echo " SCRIPT 1 COMPLETE"
echo ""
echo " Kernel installed: $KERNEL_PKG"
echo " Default kernel:   $CACHY_VMLINUZ"
echo ""
echo " NEXT STEP: Reboot then run script2-nvidia.sh"
echo " (CachyOS kernel will boot automatically)"
echo "========================================================"
