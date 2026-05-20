#version=DEVEL
# ================================================================
# Fedora 44 - Gaming VM Kickstart
# Headless, UEFI, GPU passthrough, fully hands-free
# ================================================================
#
# PROXMOX SETUP BEFORE BOOTING:
#   1. Machine type: q35
#   2. BIOS: OVMF (UEFI)
#   3. Add EFI disk — NO pre-enrolled keys (disables Secure Boot)
#   4. Add GPU passthrough device — set as Primary GPU from the start
#   5. Add dummy HDMI dongle to GPU (so it has a display to present)
#   6. Network adapter: VirtIO
#   7. Enable QEMU Guest Agent in VM options
#   8. Boot order: Network first, then disk
#
# AFTER INSTALL:
#   VM will shut down automatically when done.
#   In Proxmox: change boot order back to disk first.
#   Start VM, SSH in as gamer@<vm-ip>
#   Run: cd ~/fedora_to_cachyos && bash script1-base.sh
# ================================================================


# ================================================================
# INSTALLATION SOURCE
# ================================================================
url --url=https://mirrors.kernel.org/fedora/releases/44/Everything/x86_64/os/


# ================================================================
# LANGUAGE AND KEYBOARD
# ================================================================
lang en_US.UTF-8
keyboard --vckeymap=us --xlayouts=us


# ================================================================
# NETWORK
# ================================================================
network --bootproto=dhcp --device=link --activate --onboot=on
network --hostname=gamingvm


# ================================================================
# TIMEZONE
# ================================================================
timezone America/Chicago --utc


# ================================================================
# SECURITY
# ================================================================
rootpw --lock
selinux --enforcing


# ================================================================
# USER ACCOUNT
# NOTE: The user command MUST be a single line — no backslash
# continuations. Dracut parses the kickstart before Anaconda and
# does not support line continuation, causing "unrecognized
# arguments" errors for every wrapped line.
# ================================================================
user --name=gamer --groups=wheel,video,render,input --password=<INSERT HAS HERE> --iscrypted --gecos="Gaming VM User"


# ================================================================
# BOOTLOADER — UEFI
# NOTE: Use --location=mbr even on UEFI systems. Using
# --location=partition causes "GRUB2 does not support installation
# to a partition" error.
# ================================================================
bootloader --location=mbr --boot-drive=sda


# ================================================================
# PARTITIONING — UEFI with LVM
# ================================================================
clearpart --all --initlabel --drives=sda

part /boot/efi --fstype=efi  --size=512  --ondrive=sda
part /boot     --fstype=ext4 --size=1024 --ondrive=sda
part pv.01 --grow --ondrive=sda

volgroup vg_root pv.01

logvol / --vgname=vg_root --name=root --fstype=ext4 --size=1 --grow


# ================================================================
# PACKAGES
# ================================================================
%packages
@core
git
wget
curl
openssh-server
audit
qemu-guest-agent
%end


# ================================================================
# POST-INSTALL
# ================================================================
%post --log=/root/ks-post.log
sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config

# --- Essential services ---
systemctl enable sshd
systemctl enable qemu-guest-agent

# --- Install seatd so seat group exists ---
dnf install -y seatd
systemctl enable seatd
groupadd seat 2>/dev/null || true

# --- Add gamer to seat group ---
usermod -aG seat gamer

# --- Sudo access ---
grep -q "^%wheel" /etc/sudoers || \
    echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers

# --- Clone setup repo ---
git clone https://github.com/LordMortus/fedora_to_cachyos.git \
    /opt/fedora_to_cachyos
chmod +x /opt/fedora_to_cachyos/*.sh

# --- Copy repo to user home ---
cp -r /opt/fedora_to_cachyos /home/gamer/fedora_to_cachyos
chown -R gamer:gamer /home/gamer/fedora_to_cachyos
find /home/gamer/fedora_to_cachyos -name "*.sh" -exec chmod +x {} \;

# --- Drop start instructions ---
cat > /home/gamer/START-HERE.txt << EOF
================================================================
 Fedora Gaming VM — Post-Install
================================================================

System installed successfully.

Next steps:
  cd ~/fedora_to_cachyos
  bash script1-base.sh

Scripts will guide you through:
  1. CachyOS kernel install    (reboot required)
  2. NVIDIA driver install     (reboot required)
  3. Sunshine streaming setup  (reboot required)
  4. Niri compositor
  5. falcond performance daemon
  6. Gaming apps (Steam, Heroic, MangoHud, Gamemode)

SSH in as: gamer@<vm-ip>
================================================================
EOF
chown gamer:gamer /home/gamer/START-HERE.txt

%end


# ================================================================
# SHUTDOWN AFTER INSTALL
# ================================================================
shutdown
