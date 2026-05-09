#!/bin/bash
set -e

# =============================================================
# SCRIPT 5 OF 5 - Gaming Applications
# Run this after script 4 and a successful Moonlight connection.
# No reboot required after this script.
# =============================================================

# === VERIFY CACHYOS KERNEL IS RUNNING ===
if ! uname -r | grep -q "cachy"; then
    echo "ERROR: Not running on the CachyOS kernel!"
    echo "Current kernel: $(uname -r)"
    echo "Please reboot and select the CachyOS kernel from GRUB."
    exit 1
fi
echo "CachyOS kernel confirmed: $(uname -r)"

# === FLATPAK SETUP ===
# Ensure Flatpak is installed and Flathub is configured
sudo dnf install -y flatpak
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# === STEAM ===
# Requires RPM Fusion nonfree (enabled in script 1)
sudo dnf install -y steam

# === PROTONUP-QT ===
# GUI tool for managing Proton-GE and other compatibility layers
# Installed as a Flatpak since that's the recommended method
flatpak install -y flathub net.davidotek.pupgui2

# === HEROIC GAMES LAUNCHER ===
# Alternative to Lutris for Epic, GOG, and Amazon games
# Flatpak is the recommended install method
flatpak install -y flathub com.heroicgameslauncher.hgl

# === MANGOHUD ===
# In-game performance overlay (FPS, CPU, GPU, temps etc)
sudo dnf install -y mangohud

# === GAMEMODE ===
# Optimizes system performance while games are running
# Works automatically with Steam and Heroic
sudo dnf install -y gamemode

echo ""
echo "========================================================"
echo " SCRIPT 5 COMPLETE"
echo ""
echo " Installed:"
echo "  - Steam (via RPM Fusion)"
echo "  - ProtonUp-Qt (manage Proton-GE versions)"
echo "  - Heroic Games Launcher (Epic/GOG/Amazon)"
echo "  - MangoHud (in-game performance overlay)"
echo "  - Gamemode (automatic performance optimisation)"
echo ""
echo " TIPS:"
echo "  - Run ProtonUp-Qt after Steam first launch to install"
echo "    Proton-GE for better game compatibility"
echo "  - Enable MangoHud per-game in Steam launch options:"
echo "    MANGOHUD=1 %command%"
echo "  - Enable Gamemode per-game in Steam launch options:"
echo "    gamemoderun %command%"
echo "  - Combine both:"
echo "    MANGOHUD=1 gamemoderun %command%"
echo "========================================================"
