#version=DEVEL
# ================================================================
# Fedora 44 Minimal Kickstart - Headless Gaming VM
# ================================================================
#
# USAGE:
#   At the Fedora installer GRUB menu, press E to edit the boot
#   entry, add the following to the end of the 'linux' line:
#
#   inst.ks=https://raw.githubusercontent.com/LordMortus/fedora_to_cachyos/main/install.ks
#
#   Then press Ctrl+X to boot.
#
# WHAT THIS DOES:
#   - Installs a minimal Fedora 44 system with no desktop
#   - Creates a temporary 'setup' user for first login
#   - Enables SSH immediately
#   - On first SSH login, runs bootstrap.sh which:
#       * Asks for your desired username and password
#       * Creates your user with correct groups
#       * Clones the setup repo
#       * Starts script1-base.sh automatically
#
# PRE-REQUISITES (set in Proxmox BEFORE booting the ISO):
#   - Display device set to None
#   - GPU passthrough enabled and set as Primary GPU
#   - Network adapter added (virtio recommended)
#
# ================================================================

# === INSTALLATION SOURCE ===
url --mirrorlist=https://mirrors.fedoraproject.org/mirrorlist?repo=fedora-44&arch=x86_64

# === LANGUAGE AND KEYBOARD ===
lang en_US.UTF-8
keyboard --vckeymap=us --xlayouts=us

# === NETWORK ===
# DHCP on first available interface, enable on boot
network --bootproto=dhcp --device=link --activate --onboot=on
network --hostname=gamingvm

# === TIMEZONE ===
timezone America/Chicago --utc

# === SECURITY ===
# Root account locked - use sudo
rootpw --lock
selinux --enforcing

# === TEMPORARY SETUP USER ===
# This user is only for initial SSH access.
# bootstrap.sh will create your real user and remove this one.
# Password: setup (change after bootstrap if needed)
user --name=setup --groups=wheel --password=setup --plaintext

# === BOOTLOADER ===
bootloader --location=mbr --boot-drive=sda

# === PARTITIONING ===
clearpart --all --initlabel --drives=sda
autopart --type=lvm

# === PACKAGES ===
%packages
@core
git
wget
openssh-server
curl
audit
%end

# === POST INSTALL ===
%post --log=/root/ks-post.log

# Enable SSH on first boot
systemctl enable sshd

# Clone the setup repo to a neutral location
git clone https://github.com/LordMortus/fedora_to_cachyos.git /opt/fedora_to_cachyos
chmod +x /opt/fedora_to_cachyos/*.sh

# Wire bootstrap to run automatically on first login of setup user
cat > /home/setup/.bash_profile << 'EOF'
# Run bootstrap on first login
if [ -f /opt/fedora_to_cachyos/bootstrap.sh ]; then
    bash /opt/fedora_to_cachyos/bootstrap.sh
fi
EOF
chown setup:setup /home/setup/.bash_profile

%end

# === REBOOT AFTER INSTALL ===
reboot
