#!/bin/bash
set -e

# === ROOT CHECK ===
if [ "$EUID" -eq 0 ]; then
    echo "ERROR: Do not run this script as root!"
    echo "Run as your normal user account with sudo available."
    exit 1
fi

# =============================================================
# MASTER SETUP SCRIPT - Fedora Gaming VM (Niri Path)
# Installs CachyOS kernel, NVIDIA drivers, Sunshine, Niri
# compositor, falcond, and gaming applications.
#
# Tracks completed stages in ~/.setup-stage and resumes
# automatically after each reboot via a systemd user service.
#
# Run once — it will guide you through all stages.
# =============================================================

STAGE_FILE="$HOME/.setup-stage"
SCRIPT_PATH="$(realpath "$0")"
SERVICE_NAME="vm-setup-resume"
SERVICE_FILE="$HOME/.config/systemd/user/${SERVICE_NAME}.service"

# === HELPER FUNCTIONS ===

get_stage() {
    cat "$STAGE_FILE" 2>/dev/null || echo "0"
}

set_stage() {
    echo "$1" > "$STAGE_FILE"
}

# Detect if running interactively or from systemd service
if [ -t 0 ]; then
    INTERACTIVE=true
else
    INTERACTIVE=false
    LOG_FILE="$HOME/setup-resume.log"
    exec > >(tee -a "$LOG_FILE") 2>&1
    echo ""
    echo "=== Service auto-resume: $(date) ==="
fi

confirm() {
    local MSG="$1"
    if [ "$INTERACTIVE" = true ]; then
        read -p "${MSG} (yes/no): " REPLY
        [ "$REPLY" = "yes" ]
    else
        echo "${MSG} (yes/no): yes (auto)"
        return 0
    fi
}

confirm_reboot() {
    echo ""
    echo "--------------------------------------------------------"
    echo " A reboot is required before continuing to the next stage."
    echo "--------------------------------------------------------"
    if [ "$INTERACTIVE" = true ]; then
        if confirm "Reboot now?"; then
            echo "Rebooting..."
            sudo reboot
        else
            echo "Please reboot manually when ready, then re-run this script."
            exit 0
        fi
    else
        echo "Auto-rebooting in 10 seconds..."
        sleep 10
        sudo reboot
    fi
}

install_resume_service() {
    mkdir -p ~/.config/systemd/user/
    tee "$SERVICE_FILE" > /dev/null << EOF
[Unit]
Description=VM Setup Resume Service
After=graphical-session.target
Requires=graphical-session.target

[Service]
Type=oneshot
ExecStart=/bin/bash ${SCRIPT_PATH}
StandardOutput=append:${HOME}/setup-resume.log
StandardError=append:${HOME}/setup-resume.log

[Install]
WantedBy=graphical-session.target
EOF
    systemctl --user daemon-reload
    systemctl --user enable "$SERVICE_NAME"
}

remove_resume_service() {
    if [ -f "$SERVICE_FILE" ]; then
        systemctl --user disable "$SERVICE_NAME" 2>/dev/null || true
        rm -f "$SERVICE_FILE"
        systemctl --user daemon-reload
    fi
}

show_stage_summary() {
    local STAGE="$1"
    echo ""
    echo "========================================================"
    case "$STAGE" in
        1)
            echo " STAGE 1 of 6 - Base System & CachyOS Kernel"
            echo ""
            echo " This stage will:"
            echo "  - Check CPU architecture compatibility"
            echo "  - Update the system"
            echo "  - Install RPM Fusion repositories"
            echo "  - Install CachyOS kernel (or LTS for older CPUs)"
            echo "  - Rebuild initramfs and update GRUB"
            echo ""
            echo " A reboot into the CachyOS kernel follows."
            ;;
        2)
            echo " STAGE 2 of 6 - NVIDIA Driver"
            echo ""
            echo " This stage will:"
            echo "  - Install NVIDIA build dependencies"
            echo "  - Download and silently install the NVIDIA driver"
            echo "  - Blacklist nouveau"
            echo ""
            echo " A reboot follows after the NVIDIA installer."
            ;;
        3)
            echo " STAGE 3 of 6 - Sunshine Game Streaming"
            echo ""
            echo " This stage will:"
            echo "  - Install Sunshine from beta COPR"
            echo "  - Configure KMS capture permissions"
            echo "  - Set up auto-heal after updates"
            echo "  - Add user to input group"
            echo "  - Open firewall ports"
            echo "  - Enable Sunshine as a user service"
            echo ""
            echo " A reboot follows to apply all fixes."
            ;;
        4)
            echo " STAGE 4 of 6 - Niri Compositor"
            echo ""
            echo " This stage will:"
            echo "  - Install PipeWire"
            echo "  - Install SDDM with autologin"
            echo "  - Install Niri from COPR"
            echo "  - Install xdg-desktop-portal-gnome"
            echo "  - Wire Sunshine into the Niri session"
            echo ""
            echo " A reboot follows to start SDDM and Niri."
            ;;
        5)
            echo " STAGE 5 of 6 - falcond Performance Daemon"
            echo ""
            echo " This stage will:"
            echo "  - Install Zig build toolchain"
            echo "  - Build falcond from source"
            echo "  - Install performance profiles"
            echo "  - Enable falcond service"
            echo ""
            echo " No reboot required after this stage."
            ;;
        6)
            echo " STAGE 6 of 6 - Gaming Applications"
            echo ""
            echo " This stage will:"
            echo "  - Install Flatpak and Flathub"
            echo "  - Install Steam"
            echo "  - Install ProtonUp-Qt"
            echo "  - Install Heroic Games Launcher"
            echo "  - Install MangoHud"
            echo "  - Install Gamemode"
            echo ""
            echo " No reboot required. Setup complete after this stage!"
            ;;
    esac
    echo "========================================================"
    echo ""
}

# =============================================================
# STAGE EXECUTION
# =============================================================

STAGE=$(get_stage)

if [ "$STAGE" = "0" ]; then
    echo "========================================================"
    echo " Fedora Gaming VM - Master Setup Script (Niri Path)"
    echo ""
    echo " This script will set up your VM across 6 stages"
    echo " and multiple reboots. It will automatically resume"
    echo " after each reboot."
    echo ""
    echo " Stages:"
    echo "  1 - Base System and CachyOS Kernel"
    echo "  2 - NVIDIA Driver"
    echo "  3 - Sunshine Game Streaming"
    echo "  4 - Niri Compositor"
    echo "  5 - falcond Performance Daemon"
    echo "  6 - Gaming Applications"
    echo "========================================================"
    echo ""
    if [ "$INTERACTIVE" = true ]; then
        if ! confirm "Ready to begin setup?"; then
            echo "Exiting. Run this script again when ready."
            exit 0
        fi
    fi
    install_resume_service
    set_stage 1
    STAGE=1
fi

# =============================================================
# STAGE 1 - Base System and CachyOS Kernel
# =============================================================

if [ "$STAGE" = "1" ]; then
    show_stage_summary 1
    if [ "$INTERACTIVE" = true ]; then
        if ! confirm "Run Stage 1 now?"; then
            echo "Exiting. Run this script again when ready."
            exit 0
        fi
    fi

    echo "Checking CPU architecture compatibility..."
    ARCH_CHECK=$(/lib64/ld-linux-x86-64.so.2 --help | grep "(supported, searched)")

    if echo "$ARCH_CHECK" | grep -q "x86-64-v3"; then
        KERNEL_PKG="kernel-cachyos"
        KERNEL_DEVEL_PKG="kernel-cachyos-devel-matched"
        echo "CPU supports x86-64-v3 -- installing kernel-cachyos"
    elif echo "$ARCH_CHECK" | grep -q "x86-64-v2"; then
        KERNEL_PKG="kernel-cachyos-lts"
        KERNEL_DEVEL_PKG="kernel-cachyos-lts-devel-matched"
        echo "CPU supports x86-64-v2 -- installing kernel-cachyos-lts"
    else
        echo "ERROR: CPU does not meet minimum x86-64-v2 requirement."
        exit 1
    fi

    echo "$KERNEL_PKG" > "$HOME/.cachyos-install-variant"

    sudo dnf upgrade --refresh -y
    sudo dnf upgrade -y

    sudo dnf install -y \
        https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
        https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

    sudo dnf install -y dnf-plugins-core
    sudo setsebool -P domain_kernel_load_modules on

    echo "y" | sudo dnf copr enable bieszczaders/kernel-cachyos
    echo "y" | sudo dnf copr enable bieszczaders/kernel-cachyos-addons

    sudo dnf install -y $KERNEL_PKG $KERNEL_DEVEL_PKG
    sudo dnf install -y --allowerasing cachyos-settings scx-manager scx-scheds-git scx-tools-git

    sudo dnf upgrade --refresh -y
    sudo dnf upgrade -y

    CACHY_VER=$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' $KERNEL_PKG | tail -1)
    sudo dracut -f --kver "$CACHY_VER"
    sudo grub2-mkconfig -o /boot/grub2/grub.cfg

    CACHY_VMLINUZ=$(ls /boot/vmlinuz-*cachy* | tail -1)
    if [ -n "$CACHY_VMLINUZ" ]; then
        sudo grubby --set-default "$CACHY_VMLINUZ"
        echo "Default kernel set to: $CACHY_VMLINUZ"
    else
        echo "WARNING: Could not find CachyOS kernel in /boot - set default manually"
    fi

    set_stage 2
    echo ""
    echo "Stage 1 complete! Kernel installed: $KERNEL_PKG"
    confirm_reboot
fi

# =============================================================
# STAGE 2 - NVIDIA Driver
# =============================================================

if [ "$STAGE" = "2" ]; then
    show_stage_summary 2

    if ! uname -r | grep -q "cachy"; then
        echo "ERROR: Not running on the CachyOS kernel!"
        echo "Current kernel: $(uname -r)"
        exit 1
    fi
    echo "CachyOS kernel confirmed: $(uname -r)"

    if [ "$INTERACTIVE" = true ]; then
        if ! confirm "Run Stage 2 now?"; then
            echo "Exiting. Run this script again when ready."
            exit 0
        fi
    fi

    # 64-bit build deps
    sudo dnf install -y kernel-devel kernel-headers gcc make dkms acpid \
        libglvnd-glx libglvnd-opengl libglvnd-devel pkgconfig libxcb egl-wayland

    # 32-bit GL dispatch layer — required for Steam and 32-bit games
    sudo dnf install -y \
        libglvnd-glx.i686 \
        libglvnd-opengl.i686 \
        libglvnd-egl.i686 \
        libglvnd-gles.i686 \
        glibc.i686 \
        libstdc++.i686

    mkdir -p ~/Downloads
    cd ~/Downloads
    NVIDIA_RUN="NVIDIA-Linux-x86_64-595.71.05.run"
    if [ ! -f "$NVIDIA_RUN" ]; then
        wget https://us.download.nvidia.com/XFree86/Linux-x86_64/595.71.05/${NVIDIA_RUN}
    fi
    chmod +x "$NVIDIA_RUN"

    # Blacklist nouveau
    if ! grep -q "blacklist nouveau" /etc/modprobe.d/blacklist-nouveau.conf 2>/dev/null; then
        echo "blacklist nouveau" | sudo tee /etc/modprobe.d/blacklist-nouveau.conf
        echo "options nouveau modeset=0" | sudo tee -a /etc/modprobe.d/blacklist-nouveau.conf
    fi

    # Unload nouveau if loaded
    if lsmod | grep -q "^nouveau"; then
        echo "nouveau is loaded — unloading before NVIDIA install..."
        sudo modprobe -r nouveau || {
            echo "ERROR: Could not unload nouveau. Drop to multi-user.target and retry."
            exit 1
        }
    else
        echo "nouveau is not loaded — no action needed."
    fi

    echo "Running silent NVIDIA install..."
    sudo ~/Downloads/${NVIDIA_RUN} \
        --silent \
        --accept-license \
        --no-x-check \
        --no-nouveau-check \
        --dkms \
        --install-compat32-libs \
        2>&1 | tee ~/nvidia-install.log

    if ! /usr/bin/nvidia-smi &>/dev/null; then
        echo "ERROR: nvidia-smi failed after install."
        echo "Check the log: cat ~/nvidia-install.log"
        exit 1
    fi
    echo "NVIDIA driver installed and verified."

    set_stage 3
    echo ""
    echo "Stage 2 complete!"
    confirm_reboot
fi

# =============================================================
# STAGE 3 - Sunshine
# =============================================================

if [ "$STAGE" = "3" ]; then
    show_stage_summary 3

    if ! uname -r | grep -q "cachy"; then
        echo "ERROR: Not running on the CachyOS kernel!"
        exit 1
    fi
    if ! nvidia-smi &>/dev/null; then
        echo "ERROR: NVIDIA driver not detected!"
        exit 1
    fi
    echo "CachyOS kernel and NVIDIA driver confirmed."

    if [ "$INTERACTIVE" = true ]; then
        if ! confirm "Run Stage 3 now?"; then
            echo "Exiting. Run this script again when ready."
            exit 0
        fi
    fi

    sudo dnf install -y python3-dnf-plugin-post-transaction-actions
    echo "y" | sudo dnf copr enable lizardbyte/beta
    sudo dnf install -y Sunshine

    sudo setcap cap_sys_admin+p $(readlink -f $(which sunshine))

    sudo tee /etc/dnf/plugins/post-transaction-actions.d/sunshine.action << 'EOF'
Sunshine:in:any:/usr/bin/sunshine:execute:sudo setcap cap_sys_admin+p $(readlink -f $(which sunshine))
EOF

    sudo usermod -aG input $USER
    sudo udevadm control --reload-rules && sudo udevadm trigger -s input
    sudo grubby --update-kernel=ALL --args="nvidia_drm.modeset=1"

    # Firewall ports
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

    systemctl --user enable --now app-dev.lizardbyte.app.Sunshine

    set_stage 4
    echo ""
    echo "Stage 3 complete!"
    confirm_reboot
fi

# =============================================================
# STAGE 4 - Niri Compositor
# =============================================================

if [ "$STAGE" = "4" ]; then
    show_stage_summary 4

    if ! uname -r | grep -q "cachy"; then
        echo "ERROR: Not running on the CachyOS kernel!"
        exit 1
    fi

    if [ "$INTERACTIVE" = true ]; then
        if ! confirm "Run Stage 4 now?"; then
            echo "Exiting. Run this script again when ready."
            exit 0
        fi
    fi

    # PipeWire — required for portal-based screen capture
    sudo dnf install -y \
        pipewire \
        pipewire-pulseaudio \
        pipewire-alsa \
        wireplumber

    # SDDM
    sudo dnf install -y sddm
    sudo systemctl enable sddm

    # Niri
    echo "y" | sudo dnf copr enable yalter/niri
    sudo dnf install -y niri

    # Niri dependencies
    sudo dnf install -y \
        xdg-desktop-portal-gnome \
        xdg-desktop-portal-gtk \
        xwayland-satellite \
        alacritty \
        fuzzel \
        waybar \
        mako \
        lxpolkit \
        NetworkManager-tui \
        polkit

    # Verify niri session file exists
    if [ ! -f /usr/share/wayland-sessions/niri.desktop ]; then
        echo "ERROR: niri.desktop session file not found after install!"
        exit 1
    fi
    echo "niri.desktop session file confirmed."

    # Set graphical boot target
    # Minimal Fedora installs default to multi-user.target — SDDM
    # will be enabled but never started without this.
    sudo systemctl set-default graphical.target

    # SDDM autologin
    sudo mkdir -p /etc/sddm.conf.d/
    sudo tee /etc/sddm.conf.d/autologin.conf > /dev/null << EOF
[Autologin]
User=$USER
Session=niri.desktop

[Theme]
Current=default
EOF
    echo "SDDM autologin configured for $USER -> niri.desktop"

    # Niri config
    mkdir -p ~/.config/niri/
    tee ~/.config/niri/config.kdl > /dev/null << 'EOF'
// ~/.config/niri/config.kdl
// Minimal config tuned for a Sunshine streaming VM

input {
  keyboard {
    xkb { }
  }
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

spawn-at-startup "waybar"
spawn-at-startup "lxpolkit"

binds {
  Mod+T { spawn "alacritty"; }
  Mod+D { spawn "fuzzel"; }
  Mod+Q { close-window; }
  Mod+Shift+E { quit; }
  Mod+Shift+P { power-off-monitors; }

  Mod+Left  { focus-column-left; }
  Mod+Right { focus-column-right; }
  Mod+Up    { focus-window-up; }
  Mod+Down  { focus-window-down; }
  Mod+H     { focus-column-left; }
  Mod+L     { focus-column-right; }
  Mod+K     { focus-window-up; }
  Mod+J     { focus-window-down; }

  Mod+Shift+Left  { move-column-left; }
  Mod+Shift+Right { move-column-right; }
  Mod+Shift+H     { move-column-left; }
  Mod+Shift+L     { move-column-right; }

  Mod+F     { fullscreen-window; }
  Mod+Space { toggle-window-floating; }

  Mod+1 { focus-workspace 1; }
  Mod+2 { focus-workspace 2; }
  Mod+3 { focus-workspace 3; }
  Mod+Shift+1 { move-window-to-workspace 1; }
  Mod+Shift+2 { move-window-to-workspace 2; }
  Mod+Shift+3 { move-window-to-workspace 3; }

  Print      { screenshot; }
  Ctrl+Print { screenshot-screen; }
}
EOF
    echo "Niri config written to ~/.config/niri/config.kdl"

    # Wire Sunshine into Niri session
    systemctl --user add-wants niri.service app-dev.lizardbyte.app.Sunshine.service

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

    set_stage 5
    echo ""
    echo "Stage 4 complete!"
    echo "After rebooting, Sunshine web UI:"
    echo "  View: https://<vm-ip>:47990"
    echo "  Config changes: ssh -L 47990:localhost:47990 $(whoami)@<vm-ip>"
    echo "  Then open https://localhost:47990 in your browser."
    confirm_reboot
fi

# =============================================================
# STAGE 5 - falcond
# =============================================================

if [ "$STAGE" = "5" ]; then
    show_stage_summary 5

    if ! uname -r | grep -q "cachy"; then
        echo "ERROR: Not running on the CachyOS kernel!"
        exit 1
    fi

    if [ "$INTERACTIVE" = true ]; then
        if ! confirm "Run Stage 5 now?"; then
            echo "Exiting. Run this script again when ready."
            exit 0
        fi
    fi

    sudo dnf install -y zig git

    cd ~/Downloads
    if [ -d "falcond" ]; then
        git -C falcond pull
    else
        git clone https://git.pika-os.com/general-packages/falcond.git
    fi

    cd falcond/falcond
    rm -rf ~/.cache/zig

    if ! zig build -Doptimize=ReleaseFast 2>~/Downloads/falcond-build.log; then
        if grep -q "hash mismatch" ~/Downloads/falcond-build.log; then
            echo "Hash mismatch detected - attempting automatic fix..."

            CORRECT_HASH=$(grep "but the fetched package has" ~/Downloads/falcond-build.log | \
                grep -o '[A-Za-z0-9_$-]\{40,\}' | tail -1)

            if [ -n "$CORRECT_HASH" ]; then
                echo "Correct hash found: $CORRECT_HASH"
                OLD_HASH=$(grep -o '[A-Za-z0-9_$-]\{40,\}' build.zig.zon | head -1)
                sed -i "s/$OLD_HASH/$CORRECT_HASH/" build.zig.zon
                echo "Hash updated, retrying build..."

                if ! zig build -Doptimize=ReleaseFast 2>>~/Downloads/falcond-build.log; then
                    echo "Build failed after automatic hash fix."
                    echo "Check the log: cat ~/Downloads/falcond-build.log"
                    set_stage 5
                    exit 1
                fi
                echo "Build succeeded after automatic hash fix!"
            else
                echo "Could not extract correct hash automatically."
                echo "Manual fix required - see ~/Downloads/falcond-build.log"
                set_stage 5
                exit 1
            fi
        else
            echo "Build failed for unknown reason."
            echo "Check the log: cat ~/Downloads/falcond-build.log"
            set_stage 5
            exit 1
        fi
    fi

    sudo install -Dm755 zig-out/bin/falcond /usr/bin/falcond
    sudo install -Dm644 debian/falcond.service /etc/systemd/system/falcond.service

    cd ~/Downloads
    if [ -d "falcond-profiles" ]; then
        git -C falcond-profiles pull
    else
        git clone https://github.com/PikaOS-Linux/falcond-profiles.git
    fi

    sudo mkdir -p /usr/share/falcond/profiles
    sudo cp -r falcond-profiles/usr/share/falcond/* /usr/share/falcond/

    sudo systemctl daemon-reload
    sudo systemctl enable --now falcond

    set_stage 6
    echo ""
    echo "Stage 5 complete! No reboot needed, continuing to Stage 6..."
    echo ""
fi

# =============================================================
# STAGE 6 - Gaming Applications
# =============================================================

if [ "$STAGE" = "6" ]; then
    show_stage_summary 6

    if [ "$INTERACTIVE" = true ]; then
        if ! confirm "Run Stage 6 now?"; then
            echo "Exiting. Run this script again when ready."
            exit 0
        fi
    fi

    sudo dnf install -y flatpak
    flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

    sudo dnf install -y steam
    flatpak install --user -y flathub net.davidotek.pupgui2
    flatpak install --user -y flathub com.heroicgameslauncher.hgl
    sudo dnf install -y mangohud gamemode

    set_stage 7
    remove_resume_service
    rm -f "$STAGE_FILE"
    sudo rm -f /etc/sudoers.d/vm-setup-nopasswd

    echo ""
    echo "========================================================"
    echo " SETUP COMPLETE! (Niri Path)"
    echo ""
    echo " Your Fedora Gaming VM is fully configured."
    echo ""
    echo " Summary:"
    echo "  - CachyOS kernel ($(cat $HOME/.cachyos-install-variant 2>/dev/null || echo 'unknown'))"
    echo "  - NVIDIA GPU passthrough drivers"
    echo "  - Sunshine streaming"
    echo "  - Niri compositor (via SDDM autologin)"
    echo "  - falcond performance daemon"
    echo "  - Steam, ProtonUp-Qt, Heroic, MangoHud, Gamemode"
    echo ""
    echo " Sunshine web UI:"
    echo "  View: https://<vm-ip>:47990"
    echo "  Config: ssh -L 47990:localhost:47990 $(whoami)@<vm-ip>"
    echo "  Then open https://localhost:47990 in your browser."
    echo ""
    echo " Tips:"
    echo "  - Run ProtonUp-Qt with Steam closed to install Proton-GE"
    echo "  - Steam launch options: MANGOHUD=1 gamemoderun %command%"
    echo "  - Storage scripts (6-9) are available separately"
    echo ""
    echo " Emergency recovery if display breaks:"
    echo "  ssh in and run:"
    echo "  sudo systemctl set-default multi-user.target && sudo reboot"
    echo "========================================================"
fi
