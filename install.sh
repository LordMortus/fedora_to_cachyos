#!/bin/bash
set -e

# MAC Address for VM to keep IP: BC:24:11:C2:59:9C
# Stay on default Fedora kernel until reboot step

# == Claude AI Rewrite ===
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
sudo dnf copr enable bieszczaders/kernel-cachyos
sudo dnf copr enable bieszczaders/kernel-cachyos-addons

sudo dnf install -y kernel-cachyos kernel-cachyos-devel-matched
sudo dnf install -y --allowerasing cachyos-settings scx-manager scx-scheds-git scx-tools-git

sudo dnf upgrade --refresh -y
sudo dnf upgrade -y

# === REBUILD INITRAMFS ===
CACHY_VER=$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' kernel-cachyos | tail -1)
sudo dracut -f --kver "$CACHY_VER"

# === UPDATE GRUB ===
sudo grub2-mkconfig -o /boot/grub2/grub.cfg

# === NVIDIA DEPENDENCIES ===
sudo dnf install -y kernel-devel kernel-headers gcc make dkms acpid \
  libglvnd-glx libglvnd-opengl libglvnd-devel pkgconfig libxcb egl-wayland

# === DOWNLOAD NVIDIA DRIVER ===
mkdir -p ~/Downloads && cd ~/Downloads
sudo wget https://us.download.nvidia.com/XFree86/Linux-x86_64/595.71.05/NVIDIA-Linux-x86_64-595.71.05.run
sudo chmod +x NVIDIA-Linux-x86_64-595.71.05.run

echo ""
echo "========================================================"
echo " Reboot into CachyOS kernel, then run manually:"
echo " sudo ~/Downloads/NVIDIA-Linux-x86_64-595.71.05.run"
echo " Select NO to xconfig utility when prompted."
echo "========================================================"
