#!/bin/bash
set -e

# === ROOT CHECK ===
if [ "$EUID" -eq 0 ]; then
    echo "ERROR: Do not run this script as root!"
    echo "Run as your normal user account with sudo available."
    exit 1
fi

# =============================================================
# SCRIPT: Niri Compositor + SDDM Setup
# Alternative display path — run after scripts 1-5 are complete.
# Sets up Niri as a lightweight Wayland compositor with SDDM
# for autologin, and wires Sunshine into the Niri session.
#
# This script assumes a headless Fedora install (no existing
# desktop environment or display manager).
#
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
    echo "Please complete scripts 1-3 before running this script."
    exit 1
fi
echo "NVIDIA driver confirmed."

# === VERIFY SUNSHINE IS INSTALLED ===
if ! command -v sunshine &>/dev/null; then
    echo "ERROR: Sunshine not found!"
    echo "Please complete script3-sunshine.sh before running this script."
    exit 1
fi
echo "Sunshine confirmed."

# === PIPEWIRE ===
# Required for portal-based screen capture (Sunshine -> xdg-desktop-portal -> PipeWire)
sudo dnf install -y \
    pipewire \
    pipewire-pulseaudio \
    pipewire-alsa \
    wireplumber

# === SDDM ===
sudo dnf install -y sddm
sudo systemctl enable sddm

# === NIRI ===
echo "y" | sudo dnf copr enable yalter/niri
sudo dnf install -y niri

# === NIRI DEPENDENCIES ===
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

# nm-applet needs GTK so skip it on a minimal install;
# nmtui covers network management from a terminal if needed

# === POLKIT ===
# Required for GUI privilege escalation (sudo prompts in graphical apps)
sudo dnf install -y polkit

# === VERIFY NIRI SESSION FILE EXISTS ===
if [ ! -f /usr/share/wayland-sessions/niri.desktop ]; then
    echo "ERROR: niri.desktop session file not found after install!"
    echo "The niri package may not have installed correctly."
    exit 1
fi
echo "niri.desktop session file confirmed."

# === SET GRAPHICAL BOOT TARGET ===
# Minimal Fedora installs default to multi-user.target — SDDM
# will be enabled but never started without this.
sudo systemctl set-default graphical.target

# === SDDM AUTOLOGIN ===
sudo mkdir -p /etc/sddm.conf.d/
sudo tee /etc/sddm.conf.d/autologin.conf > /dev/null << EOF
[Autologin]
User=$USER
Session=niri.desktop

[Theme]
Current=default
EOF
echo "SDDM autologin configured for $USER -> niri.desktop"

# === NIRI CONFIG ===
mkdir -p ~/.config/niri/
tee ~/.config/niri/config.kdl > /dev/null << 'EOF'
// ~/.config/niri/config.kdl
// Minimal config tuned for a Sunshine streaming VM

input {
  keyboard {
    xkb { }
  }
  // Disable mouse acceleration for gaming
  mouse {
    accel-speed 0.0
  }
  touchpad {
    tap
  }
}

// Adjust output name to match your VM's virtual display
// Run `niri msg outputs` inside niri to find the correct name
// Common values: Virtual-1, HDMI-A-1, DP-1
output "Virtual-1" {
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

binds {
  Mod+T { spawn "alacritty"; }
  Mod+D { spawn "fuzzel"; }
  Mod+Q { close-window; }
  // Exit niri back to SDDM login screen
  Mod+Shift+E { quit; }
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

  // Move
  Mod+Shift+Left  { move-column-left; }
  Mod+Shift+Right { move-column-right; }
  Mod+Shift+H     { move-column-left; }
  Mod+Shift+L     { move-column-right; }

  // Fullscreen / float
  Mod+F     { fullscreen-window; }
  Mod+Space { toggle-window-floating; }

  // Workspaces
  Mod+1 { focus-workspace 1; }
  Mod+2 { focus-workspace 2; }
  Mod+3 { focus-workspace 3; }
  Mod+Shift+1 { move-window-to-workspace 1; }
  Mod+Shift+2 { move-window-to-workspace 2; }
  Mod+Shift+3 { move-window-to-workspace 3; }

  // Screenshots
  Print      { screenshot; }
  Ctrl+Print { screenshot-screen; }
}
EOF
echo "Niri config written to ~/.config/niri/config.kdl"

# === WIRE SUNSHINE INTO NIRI SESSION ===
# Link Sunshine to start and stop with niri
systemctl --user add-wants niri.service app-dev.lizardbyte.app.Sunshine.service

# Override: wait for Niri's Wayland socket before starting
mkdir -p ~/.config/systemd/user/app-dev.lizardbyte.app.Sunshine.service.d/
tee ~/.config/systemd/user/app-dev.lizardbyte.app.Sunshine.service.d/niri-wayland.conf > /dev/null << 'EOF'
[Unit]
After=niri.service
Requires=graphical-session.target

[Service]
Environment=XDG_CURRENT_DESKTOP=niri
Environment=XDG_SESSION_TYPE=wayland
EOF

systemctl --user daemon-reload
echo "Sunshine wired into Niri session."

echo ""
echo "========================================================"
echo " SCRIPT-NIRI COMPLETE"
echo ""
echo " Installed:"
echo "  - PipeWire (audio + screen capture backend)"
echo "  - SDDM (display manager, autologin -> niri)"
echo "  - Niri (Wayland compositor)"
echo "  - xdg-desktop-portal-gnome (Sunshine screen capture)"
echo "  - xwayland-satellite (X11 app support)"
echo "  - alacritty, fuzzel, lxpolkit"
echo ""
echo " IMPORTANT: After rebooting, open the Sunshine web UI:"
echo "   View only: https://<vm-ip>:47990 from any browser on your network"
echo "   To save config changes use an SSH tunnel (CSRF protection blocks"
echo "   saves from any origin other than localhost):"
echo "     ssh -L 47990:localhost:47990 $USER@<vm-ip>"
echo "   Then open https://localhost:47990 in your browser."
echo "   Sunshine will automatically select the best capture method."
echo ""
echo " If the output name 'Virtual-1' is wrong, fix it via SSH:"
echo "   Connect via Moonlight first to get a session, then run:"
echo "   niri msg outputs"
echo "   Edit ~/.config/niri/config.kdl with the correct name"
echo ""
echo " Emergency recovery if display breaks:"
echo "   ssh in and run:"
echo "   sudo systemctl set-default multi-user.target"
echo "   sudo systemctl restart sddm  (or reboot)"
echo ""
echo " REBOOT NOW to start SDDM and Niri."
echo "========================================================"
