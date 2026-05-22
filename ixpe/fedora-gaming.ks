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
#   7. Add VirtIO RNG device (required for entropy during UEFI PXE boot)
#   8. Enable QEMU Guest Agent in VM options
#   9. Boot order: Network first, then disk
#
# AFTER INSTALL:
#   VM will shut down automatically when done.
#   Proxmox will automatically update the boot order to disk first
#   via the API call at the end of %post — no manual steps needed.
#   Start VM, SSH in as the user defined below.
#   Run: cd ~/fedora_to_cachyos && bash script1-base.sh
#
# HANDS-FREE:
#   Username, password, hostname, VM ID, and Proxmox details are
#   all defined in the USER CONFIGURATION section below.
# ================================================================


# ================================================================
# USER CONFIGURATION
# Change these before deploying
# ================================================================

# Username, password hash, and hostname are set in the directives below.
# To generate a password hash:
#   openssl passwd -6
# (prompts interactively, nothing written to shell history)

# Proxmox API — used to flip boot order to disk after install.
# To create an API token:
#   Proxmox Web UI -> Datacenter -> API Tokens -> Add
#   User: root@pam
#   Token ID: pxe-boot
#   Uncheck "Privilege Separation"
#   Copy the secret — it is only shown once.
#
# Set the three variables below:
#   PROXMOX_HOST  — IP or hostname of your Proxmox node
#   PROXMOX_NODE  — Node name shown in Proxmox web UI (top left)
#   PROXMOX_VMID  — VM ID of this VM in Proxmox
#   PROXMOX_TOKEN — root@pam!<tokenid>=<secret>


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
network --hostname=gamingvm   # Change if wanted


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
# Groups match what the setup scripts expect:
#   wheel  — sudo access
#   video  — GPU/DRM access
#   render — GPU render node access
#   input  — mouse/keyboard (required for Sunshine)
#
# NOTE: 'seat' group is created by seatd which isn't installed yet.
# The %post section installs seatd first so the group exists
# before usermod runs. See %post below.
#
# Password is a SHA-512 hash. Generate with: openssl passwd -6
# Replace the hash below with your own.
# The placeholder hash below is NOT valid — install will fail
# if you don't replace it.
# Change --name=gamer to --name=<your user namne> if you want
# a different user name for the account in the VM.
# It is advisable not to use spaces in a user name.
#
user --name=gamer --groups=wheel,video,render,input --password=$6$REPLACETHIS$REPLACETHISWITHYOURSHA512HASHHERE --iscrypted --gecos="Gaming VM User"


# ================================================================
# BOOTLOADER — UEFI
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

# ----------------------------------------------------------------
# CONFIGURATION — edit these to match your environment
# ----------------------------------------------------------------
PROXMOX_HOST="192.168.1.210"
PROXMOX_NODE="rog"
PROXMOX_VMID="999"
PROXMOX_TOKEN="root@pam!pxe-boot=REPLACEWITHYOURTOKENSECRET"
PROXMOX_BOOT_DISK="sata0"   # sata0, scsi0, virtio0 — match your VM disk type
VM_USER="gamer"   # User must match what you changed it to!!
# ----------------------------------------------------------------

# --- Grant NOPASSWD sudo for the duration of %post ---
# Scripts called from here need passwordless sudo.
# Revoked at the end of this section.
echo "${VM_USER} ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/ks-temp-nopasswd
chmod 440 /etc/sudoers.d/ks-temp-nopasswd

# --- Essential services ---
systemctl enable sshd
systemctl enable qemu-guest-agent

# --- Allow password SSH login ---
# Fedora 44 defaults to PasswordAuthentication no
echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config

# --- Install seatd so seat group exists ---
# Must happen before we try to add the user to the seat group.
# seatd is required by Niri.
dnf install -y seatd
systemctl enable seatd
groupadd seat 2>/dev/null || true

# --- Add user to seat group ---
# The user was created by kickstart without seat (group didn't exist yet).
usermod -aG seat "${VM_USER}"

# --- Sudo access ---
grep -q "^%wheel" /etc/sudoers || \
    echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers

# --- Clone setup repo ---
git clone https://github.com/LordMortus/fedora_to_cachyos.git \
    /opt/fedora_to_cachyos
chmod +x /opt/fedora_to_cachyos/*.sh

# --- Copy repo to user home ---
USER_HOME="/home/${VM_USER}"
cp -r /opt/fedora_to_cachyos "${USER_HOME}/fedora_to_cachyos"
chown -R "${VM_USER}:${VM_USER}" "${USER_HOME}/fedora_to_cachyos"
find "${USER_HOME}/fedora_to_cachyos" -name "*.sh" -exec chmod +x {} \;

# --- Drop a start guide on first login ---
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

SSH in as: ${VM_USER}@<vm-ip>
================================================================
EOF
chown "${VM_USER}:${VM_USER}" "${USER_HOME}/START-HERE.txt"

# --- Flip Proxmox boot order to disk first ---
# Done here before shutdown so the VM boots straight to the
# installed OS on next start without touching the PXE menu.
# Note: boot order value must be URL encoded — %3D is = and %3B is ;
# Format: order=<disk>;<net> e.g. sata0;net0
echo "Setting Proxmox boot order to disk first..."
curl -sk \
    -X PUT \
    "https://${PROXMOX_HOST}:8006/api2/json/nodes/${PROXMOX_NODE}/qemu/${PROXMOX_VMID}/config" \
    -H "Authorization: PVEAPIToken=${PROXMOX_TOKEN}" \
    -d "boot=order%3D${PROXMOX_BOOT_DISK}%3Bnet0" \
    && echo "Boot order updated successfully." \
    || echo "WARNING: Failed to update boot order. Change manually in Proxmox before starting VM."

# --- Revoke temporary NOPASSWD sudo ---
rm -f /etc/sudoers.d/ks-temp-nopasswd

%end


# ================================================================
# SHUTDOWN AFTER INSTALL
# ================================================================
# VM shuts down when install completes.
# Boot order is already flipped to disk via the API call above.
# Just start the VM in Proxmox when ready.
shutdown
