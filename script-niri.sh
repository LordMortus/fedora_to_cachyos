#!/bin/bash
set -e

# === ROOT CHECK ===
if [ "$EUID" -eq 0 ]; then
    echo "ERROR: Do not run this script as root!"
    echo "Run as your normal user account with sudo available."
    exit 1
fi

# =============================================================
# SCRIPT - Niri Wayland Compositor + Sunshine (Headless)
#
# This is an ALTERNATIVE to script3-sunshine.sh for users who
# want a lightweight tiling compositor instead of KDE Plasma.
#
# PRE-REQUISITES - Complete these BEFORE running this script:
#   1. Scripts 1 and 2 must be complete (CachyOS + NVIDIA)
#   2. In Proxmox: set the VM display device to "none"
#      Hardware -> Display -> None
#      This prevents the virtual VGA conflicting with NVIDIA.
#   3. Reboot after removing the display device
#   4. SSH must be working (it's your only way in/out)
#
# WHAT THIS SCRIPT DOES:
#   - Installs greetd + seatd (lightweight display/seat manager)
#   - Installs niri and supporting Wayland packages
#   - Configures greetd for autologin into niri
#   - Sets up niri config with correct NVIDIA GPU selection
#   - Wires Sunshine into the niri systemd session
#   - Fixes locale for display manager compatibility
#
# AFTER REBOOT:
#   - Connect via Moonlight
#   - Access Sunshine web UI via SSH tunnel:
#       ssh -L 47990:localhost:47990 <user>@<vm-ip>
#       then open https://localhost:47990 in browser
#   - Create Sunshine admin account and pair Moonlight
#
# REBOOT when complete, then connect via Moonlight.
# =============================================================

# === VERIFY CACHYOS KERNEL IS RUNNING ===
if ! uname -r | grep -q "cachy"; then
    echo "ERROR: Not running on the CachyOS kernel!"
    echo "Current kernel: $(uname -r)"
    exit 1
fi
echo "CachyOS kernel confirmed: $(uname -r)"

# === VERIFY NVIDIA DRIVER IS LOADED ===
if ! nvidia-smi &>/dev/null; then
    echo "ERROR: NVIDIA driver not detected!"
    echo "Please run script2-nvidia.sh first."
    exit 1
fi
echo "NVIDIA driver confirmed."

# === VERIFY NO CONFLICTING DISPLAY DEVICE ===
# The Proxmox virtual VGA (bochs-drm) conflicts with NVIDIA
# and causes niri to render to the wrong GPU (black screen).
if ls /sys/class/drm/ | grep -q "card.*Virtual"; then
    echo ""
    echo "WARNING: Virtual display device detected!"
    echo "This will cause a black screen in niri."
    echo ""
    echo "In Proxmox: Hardware -> Display -> set to None"
    echo "Then reboot and re-run this script."
    echo ""
    read -p "Continue anyway? (yes/no): " CONTINUE
    if [ "$CONTINUE" != "yes" ]; then
        exit 1
    fi
fi

# === DETECT NVIDIA CARD ===
# Card number varies depending on boot order - detect dynamically
NVIDIA_CARD=$(grep -rl '0x10de' /sys/class/drm/card*/device/vendor 2>/dev/null | \
    grep -o 'card[0-9]' | head -1)
if [ -z "$NVIDIA_CARD" ]; then
    echo "ERROR: Could not detect NVIDIA DRM device."
    echo "Check that nvidia_drm.modeset=1 is set and /dev/dri/card* exists."
    exit 1
fi
NVIDIA_DRI="/dev/dri/${NVIDIA_CARD}"
echo "NVIDIA GPU detected at: ${NVIDIA_DRI}"

# === FIX LOCALE ===
# Display managers and Qt apps require UTF-8 locale.
# Without this, some display manager helpers crash on launch.
echo "Setting system locale to UTF-8..."
sudo localectl set-locale LANG=en_US.UTF-8
sudo localedef -i en_US -f UTF-8 en_US.UTF-8 2>/dev/null || true

# === INSTALL GREETD AND SEATD ===
# greetd: lightweight display manager for Wayland sessions
# seatd: seat management daemon required by niri for device access
echo "Installing greetd and seatd..."
sudo dnf install -y greetd seatd

# === ADD USER TO SEAT GROUP ===
# Required for seatd device access - takes effect after reboot
sudo usermod -aG seat $USER
echo "Added ${USER} to seat group."

# === ENABLE SEATD ===
sudo systemctl enable --now seatd

# === CONFIGURE GREETD FOR AUTOLOGIN ===
# [initial_session] triggers autologin on first boot
# [default_session] handles subsequent sessions
echo "Configuring greetd autologin..."
sudo mkdir -p /etc/greetd
sudo tee /etc/greetd/config.toml > /dev/null << EOF
[terminal]
vt = 1

[default_session]
command = "niri-session"
user = "${USER}"

[initial_session]
command = "niri-session"
user = "${USER}"
EOF

# === ENABLE GREETD ===
# Disable any existing display manager that may conflict
sudo systemctl disable plasmalogin 2>/dev/null || true
sudo systemctl disable sddm 2>/dev/null || true
sudo systemctl disable gdm 2>/dev/null || true

sudo systemctl enable greetd

# === ADD GREETD TO GRAPHICAL TARGET ===
# systemctl enable alone is not always sufficient -
# explicit symlink ensures greetd starts with graphical.target
sudo mkdir -p /etc/systemd/system/graphical.target.wants
sudo ln -sf /usr/lib/systemd/system/greetd.service \
    /etc/systemd/system/graphical.target.wants/greetd.service
sudo systemctl daemon-reload

# === INSTALL NIRI AND SUPPORTING PACKAGES ===
echo "Installing niri..."
echo "y" | sudo dnf copr enable yalter/niri
sudo dnf install -y niri

echo "Installing Wayland support packages..."
sudo dnf install -y \
    xdg-desktop-portal-gnome \
    xdg-desktop-portal-gtk \
    xwayland-satellite \
    alacritty \
    fuzzel \
    waybar \
    mako \
    lxpolkit \
    NetworkManager-tui

# === CREATE NIRI CONFIG ===
mkdir -p ~/.config/niri
cat > ~/.config/niri/config.kdl << EOF
// ~/.config/niri/config.kdl
// Niri config for headless Fedora gaming VM with NVIDIA GPU passthrough

// === GPU SELECTION ===
// Forces niri to use the NVIDIA GPU instead of any virtual display device.
// GBM backend required for NVIDIA Wayland rendering.
environment {
    WLR_DRM_DEVICES "${NVIDIA_DRI}"
    GBM_BACKEND "nvidia-drm"
    __GLX_VENDOR_LIBRARY_NAME "nvidia"
    LIBVA_DRIVER_NAME "nvidia"
}

input {
    keyboard {
        xkb { }
    }
    mouse {
        // Disable mouse acceleration for gaming
        accel-speed 0.0
    }
}

// Output config - HDMI-A-1 is typical for NVIDIA passthrough with dummy plug.
// If the screen is black after connecting, SSH in and run:
//   niri msg outputs
// Then update the output name below to match.
output "HDMI-A-1" {
    mode "1920x1080@60.000"
    scale 1.0
}

layout {
    gaps 8
    center-focused-column "never"
    default-column-width { proportion 0.5; }
    focus-ring {
        width 2
        active-color "#7fc8ff"
        inactive-color "#505050"
    }
}

prefer-no-csd

screenshot-path "~/Pictures/screenshots/%Y-%m-%d %H:%M:%S.png"

// Autostart
spawn-at-startup "waybar"
spawn-at-startup "lxpolkit"
spawn-at-startup "nm-applet" "--indicator"

binds {
    // Terminal
    Mod+T { spawn "alacritty"; }
    // App launcher
    Mod+D { spawn "fuzzel"; }
    // Close window
    Mod+Q { close-window; }
    // Exit niri
    Mod+Shift+E { quit; }
    // Power off monitors
    Mod+Shift+P { power-off-monitors; }

    // Focus
    Mod+Left  { focus-column-left; }
    Mod+Right { focus-column-right; }
    Mod+Up    { focus-window-up; }
    Mod+Down  { focus-window-down; }
    Mod+H     { focus-column-left; }
    Mod+L     { focus-column-right; }
    Mod+K     { focus-window-up; }
    Mod+J     { focus-window-down; }

    // Move windows
    Mod+Shift+Left  { move-column-left; }
    Mod+Shift+Right { move-column-right; }
    Mod+Shift+H     { move-column-left; }
    Mod+Shift+L     { move-column-right; }

    // Fullscreen and float
    Mod+F     { fullscreen-window; }
    Mod+Space { toggle-window-floating; }

    // Workspaces
    Mod+1 { focus-workspace 1; }
    Mod+2 { focus-workspace 2; }
    Mod+3 { focus-workspace 3; }
    Mod+4 { focus-workspace 4; }
    Mod+Shift+1 { move-window-to-workspace 1; }
    Mod+Shift+2 { move-window-to-workspace 2; }
    Mod+Shift+3 { move-window-to-workspace 3; }
    Mod+Shift+4 { move-window-to-workspace 4; }

    // Screenshots
    Print      { screenshot; }
    Ctrl+Print { screenshot-screen; }
}
EOF

echo "Niri config written to ~/.config/niri/config.kdl"

# === WIRE SUNSHINE INTO NIRI SESSION ===
# Link Sunshine to start and stop with the niri session
systemctl --user add-wants niri.service app-dev.lizardbyte.app.Sunshine.service 2>/dev/null || true

# Create override so Sunshine waits for niri's Wayland socket
mkdir -p ~/.config/systemd/user/app-dev.lizardbyte.app.Sunshine.service.d/
cat > ~/.config/systemd/user/app-dev.lizardbyte.app.Sunshine.service.d/niri-wayland.conf << 'EOF'
[Unit]
After=niri.service
Requires=graphical-session.target

[Service]
Environment=XDG_CURRENT_DESKTOP=niri
Environment=XDG_SESSION_TYPE=wayland
EOF

systemctl --user daemon-reload

# === FIREWALL PORTS FOR SUNSHINE ===
# Already done by script3 if run, but included here for standalone use
sudo firewall-cmd --permanent --add-port=47984/tcp 2>/dev/null || true
sudo firewall-cmd --permanent --add-port=47989/tcp 2>/dev/null || true
sudo firewall-cmd --permanent --add-port=47990/tcp 2>/dev/null || true
sudo firewall-cmd --permanent --add-port=48010/tcp 2>/dev/null || true
sudo firewall-cmd --permanent --add-port=47998/udp 2>/dev/null || true
sudo firewall-cmd --permanent --add-port=47999/udp 2>/dev/null || true
sudo firewall-cmd --permanent --add-port=48000/udp 2>/dev/null || true
sudo firewall-cmd --permanent --add-port=48002/udp 2>/dev/null || true
sudo firewall-cmd --permanent --add-port=48010/udp 2>/dev/null || true
sudo firewall-cmd --reload 2>/dev/null || true

echo ""
echo "========================================================"
echo " SCRIPT-NIRI COMPLETE"
echo ""
echo " NVIDIA GPU:  ${NVIDIA_DRI}"
echo " Compositor:  niri $(niri --version 2>/dev/null || echo 'installed')"
echo " Login mgr:   greetd (autologin as ${USER})"
echo ""
echo " IMPORTANT: Reboot now for seat group membership to"
echo " take effect. Without this niri cannot access the GPU."
echo ""
echo " AFTER REBOOT:"
echo "  1. Connect via Moonlight"
echo "  2. To access Sunshine web UI, use an SSH tunnel:"
echo "       ssh -L 47990:localhost:47990 ${USER}@<vm-ip>"
echo "     Then open: https://localhost:47990"
echo "  3. Create your Sunshine admin account"
echo "  4. Enter the PIN shown in Moonlight"
echo ""
echo " IF YOU GET A BLACK SCREEN:"
echo "  - SSH in and check: journalctl --user -u niri.service -n 30"
echo "  - Verify NVIDIA card: ls /dev/dri/"
echo "  - Check output name: niri msg outputs"
echo "    Update output name in ~/.config/niri/config.kdl if needed"
echo "  - Restart niri: systemctl --user restart niri.service"
echo ""
echo " KEY BINDINGS (Super/Windows key = Mod):"
echo "  Mod+T        Terminal (alacritty)"
echo "  Mod+D        App launcher (fuzzel)"
echo "  Mod+Q        Close window"
echo "  Mod+F        Fullscreen"
echo "  Mod+Space    Toggle floating"
echo "  Mod+H/L      Focus left/right"
echo "  Mod+1-4      Switch workspace"
echo "  Mod+Shift+E  Exit niri"
echo "========================================================"
