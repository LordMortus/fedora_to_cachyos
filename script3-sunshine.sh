#!/bin/bash
set -e

# === ROOT CHECK ===
if [ "$EUID" -eq 0 ]; then
    echo "ERROR: Do not run this script as root!"
    echo "Run as your normal user account with sudo available."
    exit 1
fi

# =============================================================
# SCRIPT 3 OF 5 - Sunshine Game Streaming Host
# Run this on the CachyOS kernel AFTER rebooting from script 2.
# Verify NVIDIA drivers are loaded before continuing:
#   nvidia-smi   (should show your GPU)
# REBOOT when complete.
# =============================================================

# === VERIFY CACHYOS KERNEL IS RUNNING ===
if ! uname -r | grep -q "cachy"; then
    echo "ERROR: Not running on the CachyOS kernel!"
    echo "Current kernel: $(uname -r)"
    echo "Please reboot and select the CachyOS kernel from GRUB."
    exit 1
fi
echo "CachyOS kernel confirmed: $(uname -r)"

# === VERIFY NVIDIA DRIVER IS LOADED ===
if ! nvidia-smi &>/dev/null; then
    echo "ERROR: NVIDIA driver not detected!"
    echo "Please run the NVIDIA installer first:"
    echo "  sudo ~/Downloads/NVIDIA-Linux-x86_64-595.71.05.run"
    exit 1
fi
echo "NVIDIA driver confirmed."

# === INSTALL DNF POST-TRANSACTION PLUGIN ===
sudo dnf install -y python3-dnf-plugin-post-transaction-actions

# === ENABLE SUNSHINE BETA COPR AND INSTALL ===
sudo dnf copr enable lizardbyte/beta
sudo dnf install -y Sunshine

# === GRANT KMS CAPTURE CAPABILITY ===
sudo setcap cap_sys_admin+p $(readlink -f $(which sunshine))

# === AUTO-REAPPLY SETCAP AFTER SUNSHINE UPDATES ===
sudo tee /etc/dnf/plugins/post-transaction-actions.d/sunshine.action << 'EOF'
Sunshine:in:any:/usr/bin/sunshine:execute:sudo setcap cap_sys_admin+p $(readlink -f $(which sunshine))
EOF

# === ADD USER TO INPUT GROUP ===
sudo usermod -aG input $USER

# === RELOAD UDEV RULES ===
sudo udevadm control --reload-rules && sudo udevadm trigger -s input

# === NVIDIA: ENABLE DRM MODESETTING ===
sudo grubby --update-kernel=ALL --args="nvidia_drm.modeset=1"

# === KWIN: DISABLE OVERLAY PLANES ===
mkdir -p ~/.config/plasma-workspace/env
tee ~/.config/plasma-workspace/env/kwin-sunshine.sh << 'EOF'
export KWIN_USE_OVERLAYS=0
EOF
chmod +x ~/.config/plasma-workspace/env/kwin-sunshine.sh

# === FIREWALL: OPEN SUNSHINE PORTS ===
sudo firewall-cmd --permanent --add-port=47984/tcp
sudo firewall-cmd --permanent --add-port=47989/tcp
sudo firewall-cmd --permanent --add-port=47990/tcp
sudo firewall-cmd --permanent --add-port=48010/tcp
sudo firewall-cmd --permanent --add-port=47998/udp
sudo firewall-cmd --permanent --add-port=47999/udp
sudo firewall-cmd --permanent --add-port=48000/udp
sudo firewall-cmd --permanent --add-port=48002/udp
sudo firewall-cmd --permanent --add-port=48010/udp
sudo firewall-cmd --reload

# === DISABLE SCREEN LOCK AND POWER MANAGEMENT ===
# Prevents 503 errors by ensuring Sunshine always has
# an active display to capture regardless of idle time

# Disable screen lock
kwriteconfig6 --file kscreenlockerrc --group Daemon --key Autolock false
kwriteconfig6 --file kscreenlockerrc --group Daemon --key LockOnResume false

# Disable display power management
kwriteconfig6 --file powermanagementprofilesrc --group "AC" --group "DPMSControl" --key idleTime 0
kwriteconfig6 --file powermanagementprofilesrc --group "AC" --group "DPMSControl" --key lockBeforeSleep false

# Disable screen blanking
kwriteconfig6 --file powermanagementprofilesrc --group "AC" --group "Display" --key turnOffDisplayIdleTimeEnabled false

# Disable screen energy saving
kwriteconfig6 --file powermanagementprofilesrc --group "AC" --group "Display" --key dimDisplayIdleTimeEnabled false

# Apply changes without needing a reboot
qdbus6 org.kde.KWin /org/kde/KWin reconfigure 2>/dev/null || true

# === ENABLE SUNSHINE AS USER SERVICE ===
systemctl --user enable --now app-dev.lizardbyte.app.Sunshine

echo ""
echo "========================================================"
echo " SCRIPT 3 COMPLETE"
echo ""
echo " Sunshine is installed and running."
echo " Web UI: https://localhost:47990"
echo " (Ignore the self-signed SSL warning)"
echo ""
echo " First-time setup:"
echo "  1. Open https://localhost:47990 in your browser"
echo "  2. Create your admin username and password"
echo "  3. In Moonlight on your client, add this PC"
echo "  4. Enter the PIN shown in Moonlight when prompted"
echo "     in the Sunshine web UI"
echo ""
echo " IMPORTANT: REBOOT before running script4-falcond.sh"
echo " The following require a reboot to take effect:"
echo "  - input group membership (mouse/keyboard)"
echo "  - nvidia_drm.modeset=1 (black screen fix)"
echo "  - KWIN_USE_OVERLAYS=0 (window flicker fix)"
echo "  - Screen lock and power management settings"
echo ""
echo " If streaming breaks after a future 'dnf upgrade',"
echo " the post-transaction hook restores setcap automatically."
echo " If needed, re-run manually:"
echo "   sudo setcap cap_sys_admin+p \$(readlink -f \$(which sunshine))"
echo "========================================================"
