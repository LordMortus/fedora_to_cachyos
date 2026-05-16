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
# PROXMOX SETUP ORDER:
#   1. Add display device temporarily (so you can see GRUB)
#   2. Add GPU passthrough (not primary yet)
#   3. Add network adapter (virtio recommended)
#   4. Enable QEMU Guest Agent in VM options
#   5. Boot ISO, add inst.ks= to GRUB, let install run
#   6. When VM powers off:
#      - Remove display device
#      - Set GPU as Primary GPU
#   7. Start VM, check Proxmox Summary tab for IP
#   8. SSH in:  ssh setup@<vm-ip>  (password: setup)
#      bootstrap.sh runs automatically and will:
#        - Ask for your username, password, and hostname
#        - Create your user with correct groups
#        - Clone the setup repo
#        - Start script1-base.sh automatically
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
# Password: setup (removed after bootstrap completes)
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
qemu-guest-agent
%end

# === POST INSTALL ===
%post --log=/root/ks-post.log

# Enable SSH on first boot
systemctl enable sshd

# Enable QEMU guest agent so Proxmox can show IP in Summary tab
systemctl enable qemu-guest-agent

# Clone the setup repo to a neutral location
git clone https://github.com/LordMortus/fedora_to_cachyos.git /opt/fedora_to_cachyos
chmod +x /opt/fedora_to_cachyos/*.sh

# Wire bootstrap to run automatically on first login of setup user
# Written as explicit commands rather than heredoc for kickstart compatibility
PROFILE=/home/setup/.bash_profile
echo '#!/bin/bash' > $PROFILE
echo 'if [ -f /opt/fedora_to_cachyos/bootstrap.sh ]; then' >> $PROFILE
echo '    bash /opt/fedora_to_cachyos/bootstrap.sh' >> $PROFILE
echo 'fi' >> $PROFILE
chown setup:setup $PROFILE
chmod 644 $PROFILE

%end

# === SHUTDOWN AFTER INSTALL ===
# Gives you time to remove display device and set GPU as primary
# before first boot
shutdown
