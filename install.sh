#!/bin/bash
set -e

# MAC Address for VM to keep IP: BC:24:11:C2:59:9C
# Stay on default Fedora kernel until reboot step

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
cd ~/Downloads
wget https://us.download.nvidia.com/XFree86/Linux-x86_64/595.71.05/NVIDIA-Linux-x86_64-595.71.05.run
chmod +x NVIDIA-Linux-x86_64-595.71.05.run

echo ""
echo "========================================================"
echo " Reboot into CachyOS kernel, then run manually:"
echo " sudo ~/Downloads/NVIDIA-Linux-x86_64-595.71.05.run"
echo " Select NO to xconfig utility when prompted."
echo " Then re-run this script from the FALCOND section,"
echo " or run the falcond section manually."
echo "========================================================"

# === FALCOND (build from source - no Fedora 44 RPM available yet) ===
# Uncomment and run this section AFTER rebooting into CachyOS kernel

# sudo dnf install -y zig git libadwaita-devel lua-devel
# cd ~/Downloads
# git clone https://git.pika-os.com/general-packages/falcond
# cd falcond
# zig build -Doptimize=ReleaseFast -Dcpu=baseline
# sudo install -Dm755 zig-out/bin/falcond /usr/bin/falcond
# sudo install -Dm644 debian/falcond.service /etc/systemd/system/falcond.service

# # Profiles
# cd ~/Downloads
# git clone https://github.com/PikaOS-Linux/falcond-profiles
# sudo cp -r falcond-profiles/profiles /etc/falcond/

# # GUI (optional)
# git clone https://git.pika-os.com/custom-gui-packages/falcond-gui
# cd falcond-gui
# # Follow build instructions in the repo README

# sudo systemctl daemon-reload
# sudo systemctl enable --now falcond
