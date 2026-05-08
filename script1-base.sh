#!/bin/bash
set -e

# =============================================================
# SCRIPT 1 OF 4 - Base Setup & CachyOS Kernel
# Run this first, on the default Fedora kernel.
# REBOOT INTO CACHYOS KERNEL when complete.
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
sudo dnf copr enable bieszczaders/kernel-cachyos -y
sudo dnf copr enable bieszczaders/kernel-cachyos-addons -y

sudo dnf install -y $KERNEL_PKG $KERNEL_DEVEL_PKG
sudo dnf install -y --allowerasing cachyos-settings scx-manager scx-scheds-git scx-tools-git

sudo dnf upgrade --refresh -y
sudo dnf upgrade -y

# === REBUILD INITRAMFS ===
CACHY_VER=$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' $KERNEL_PKG | tail -1)
sudo dracut -f --kver "$CACHY_VER"

# === UPDATE GRUB ===
sudo grub2-mkconfig -o /boot/grub2/grub.cfg

echo ""
echo "========================================================"
echo " SCRIPT 1 COMPLETE"
echo ""
echo " Kernel installed: $KERNEL_PKG"
echo ""
echo " NEXT STEP: Reboot and select the CachyOS kernel"
echo " from the GRUB menu, then run script2-nvidia.sh"
echo "========================================================"
