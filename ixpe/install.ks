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
# BOOT THIS KICKSTART VIA PXE:
#   iPXE menu → Fedora 44 Gaming VM
#   Or manually: add inst.ks=http://<truenas-ip>/boot/fedora/fedora-gaming.ks
#   to the kernel line
#
# AFTER INSTALL:
#   VM will shut down automatically when done.
#   In Proxmox: change boot order back to disk first.
#   Start VM, SSH in as the user defined below.
#   Run: cd ~/fedora_to_cachyos && bash script1-base.sh
#   (or setup-master.sh when that's ready)
#
# HANDS-FREE:
#   Username, password, and hostname are defined here.
#   bootstrap.sh is NOT used in this path — user is created
#   directly by kickstart with the correct groups.
#   Change the values in the USER CONFIGURATION section below.
# ================================================================


# ================================================================
# USER CONFIGURATION
# Change these before deploying
# ================================================================

# These are set via kickstart user/network directives below.
# Keeping them up here makes them easy to find and change.
#
# Username:  set in `user --name=` line
# Password:  set in `user --password=` line (hashed — see note)
# Hostname:  set in `network --hostname=` line
#
# To generate a password hash:
#   python3 -c "import crypt; print(crypt.crypt('yourpassword', crypt.mksalt(crypt.METHOD_SHA512)))"
# Or use openssl:
#   openssl passwd -6 yourpassword


# ================================================================
# INSTALLATION SOURCE
# ================================================================
url --mirrorlist=https://mirrors.fedoraproject.org/mirrorlist?repo=fedora-44&arch=x86_64


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
# ================================================================
# Groups match what bootstrap.sh was setting:
#   wheel  — sudo access
#   video  — GPU/DRM access
#   render — GPU render node access
#   input  — mouse/keyboard (required for Sunshine)
#   seat   — seat management (required for Niri/SDDM)
#
# NOTE: 'seat' group is created by seatd which isn't installed yet.
# The %post section installs seatd first so the group exists
# before useradd runs. See %post below.
#
# Password is set as a SHA-512 hash. To generate:
#   openssl passwd -6 yourpassword
# Replace the hash below with your own.
# The placeholder hash below is NOT valid — the install will fail
# if you don't replace it.
#
user --name=gamer \
     --groups=wheel,video,render,input \
     --password=$6$REPLACETHIS$REPLACETHISWITHYOURSHA512HASHHERE \
     --iscrypted \
     --gecos="Gaming VM User"


# ================================================================
# BOOTLOADER — UEFI
# ================================================================
# --location=partition is correct for UEFI (not mbr)
# --boot-drive matches the primary disk in Proxmox (usually sda or vda)
bootloader --location=partition --boot-drive=sda


# ================================================================
# PARTITIONING — UEFI with LVM
# ================================================================
clearpart --all --initlabel --drives=sda

# EFI system partition — required for UEFI boot
part /boot/efi --fstype=efi  --size=512  --ondrive=sda

# Separate /boot — keeps kernel updates clean, required for dracut
part /boot     --fstype=ext4 --size=1024 --ondrive=sda

# LVM physical volume — takes remaining space
part pv.01 --grow --ondrive=sda

# Volume group
volgroup vg_root pv.01

# Root logical volume — grows to fill the VG
logvol / \
    --vgname=vg_root \
    --name=root \
    --fstype=ext4 \
    --grow


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
# seatd installed in %post (needed before user group assignment)
%end


# ================================================================
# POST-INSTALL
# ================================================================
%post --log=/root/ks-post.log

# --- Essential services ---
systemctl enable sshd
systemctl enable qemu-guest-agent

# --- Install seatd so seat group exists ---
# Must happen before we try to add the user to the seat group.
# seatd is required by Niri.
dnf install -y seatd
systemctl enable seatd
groupadd seat 2>/dev/null || true

# --- Add user to seat group ---
# The user was created by kickstart without seat (group didn't exist yet).
# Add them now that seatd has created it.
USERNAME=$(grep "^user --name=" /root/anaconda-ks.cfg 2>/dev/null | \
    sed 's/.*--name=\([^ ]*\).*/\1/' || echo "gamer")
usermod -aG seat "$USERNAME"

# --- Sudo access ---
grep -q "^%wheel" /etc/sudoers || \
    echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers

# --- Clone setup repo ---
git clone https://github.com/LordMortus/fedora_to_cachyos.git \
    /opt/fedora_to_cachyos
chmod +x /opt/fedora_to_cachyos/*.sh

# --- Copy repo to user home ---
USER_HOME="/home/${USERNAME}"
cp -r /opt/fedora_to_cachyos "${USER_HOME}/fedora_to_cachyos"
chown -R "${USERNAME}:${USERNAME}" "${USER_HOME}/fedora_to_cachyos"
find "${USER_HOME}/fedora_to_cachyos" -name "*.sh" -exec chmod +x {} \;

# --- Drop a README on the desktop so first SSH login is obvious ---
cat > "${USER_HOME}/START-HERE.txt" << EOF
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

SSH in as: ${USERNAME}@<vm-ip>
================================================================
EOF
chown "${USERNAME}:${USERNAME}" "${USER_HOME}/START-HERE.txt"

%end


# ================================================================
# SHUTDOWN AFTER INSTALL
# ================================================================
# VM shuts down when install completes.
# In Proxmox: change boot order to disk before starting again.
shutdown
