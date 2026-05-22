#!/bin/bash
set -e

# === ROOT CHECK ===
if [ "$EUID" -eq 0 ]; then
    echo "ERROR: Do not run this script as root!"
    echo "Run as your normal user account with sudo available."
    exit 1
fi

# =============================================================
# MASTER SETUP SCRIPT - Fedora Gaming VM (KDE Plasma Path)
# Installs CachyOS kernel, NVIDIA drivers, Sunshine, KDE Plasma,
# falcond, and gaming applications.
#
# NOTE: KDE Plasma must already be installed before running
# this script. Install it via:
#   sudo dnf install -y @kde-desktop-environment
# then reboot into the KDE session before continuing.
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
            echo " STAGE 1 of 5 - Base System & CachyOS Kernel"
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
            echo " STAGE 2 of 5 - NVIDIA Driver"
            echo ""
            echo " This stage will:"
            echo "  - Install NVIDIA build dependencies"
            echo "  - Download and silently install the NVIDIA driver"
            echo "  - Blacklist nouveau"
            echo ""
            echo " A reboot follows after the NVIDIA installer."
            ;;
        3)
            echo " STAGE 3 of 5 - Sunshine Game Streaming"
            echo ""
            echo " This stage will:"
            echo "  - Install Sunshine from beta COPR"
            echo "  - Configure KMS capture permissions"
            echo "  - Set up auto-heal after updates"
            echo "  - Add user to input group"
            echo "  - Open firewall ports"
            echo "  - Apply KWin overlay fix"
            echo "  - Disable screen lock and power management"
            echo "  - Enable Sunshine as a user service"
            echo ""
            echo " A reboot follows to apply all fixes."
            ;;
        4)
            echo " STAGE 4 of 5 - falcond Performance Daemon"
            echo ""
            echo " This stage will:"
            echo "  - Install Zig build toolchain"
            echo "  - Build falcond from source"
            echo "  - Install performance profiles"
            echo "  - Enable falcond service"
            echo ""
            echo " No reboot required after this stage."
            ;;
        5)
            echo " STAGE 5 of 5 - Gaming Applications"
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
    echo " Fedora Gaming VM - Master Setup Script (KDE Path)"
    echo ""
    echo " This script will set up your VM across 5 stages"
    echo " and multiple reboots. It will automatically resume"
    echo " after each reboot."
    echo ""
    echo " Stages:"
    echo "  1 - Base System and CachyOS Kernel"
    echo "  2 - NVIDIA Driver"
    echo "  3 - Sunshine Game Streaming"
    echo "  4 - falcond Performance Daemon"
    echo "  5 - Gaming Applications"
    echo "========================================================"
    echo ""

    # Verify KDE is installed before starting
    if ! command -v kwriteconfig6 &>/dev/null && ! rpm -q plasma-desktop &>/dev/null 2>/dev/null; then
        echo "WARNING: KDE Plasma does not appear to be installed."
        echo "Install it first with:"
        echo "  sudo dnf install -y @kde-desktop-environment"
        echo "Then reboot into KDE and re-run this script."
        echo ""
        if [ "$INTERACTIVE" = true ]; then
            if ! confirm "Continue anyway?"; then
                exit 0
            fi
        fi
    fi

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

    # Akonadi fix
    if command -v akonadictl &>/dev/null; then
        if ! rpm -q akonadi-server &>/dev/null; then
            echo "KDE PIM not installed - masking Akonadi to prevent crashes..."
            akonadictl stop 2>/dev/null || true
            rm -rf ~/.local/share/akonadi/
            systemctl --user mask akonadi.service
            systemctl --user mask akonadi.socket
        else
            echo "KDE PIM detected - leaving Akonadi enabled."
        fi
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

    # KDE-specific configuration
    # Disable overlay planes to prevent window flicker during streaming
    mkdir -p ~/.config/plasma-workspace/env
    tee ~/.config/plasma-workspace/env/kwin-sunshine.sh << 'EOF'
export KWIN_USE_OVERLAYS=0
EOF
    chmod +x ~/.config/plasma-workspace/env/kwin-sunshine.sh

    # Disable screen lock
    kwriteconfig6 --file kscreenlockerrc --group Daemon --key Autolock false
    kwriteconfig6 --file kscreenlockerrc --group Daemon --key LockOnResume false

    # Disable display power management (prevents 503 errors)
    kwriteconfig6 --file powermanagementprofilesrc --group "AC" --group "DPMSControl" --key idleTime 0
    kwriteconfig6 --file powermanagementprofilesrc --group "AC" --group "DPMSControl" --key lockBeforeSleep false
    kwriteconfig6 --file powermanagementprofilesrc --group "AC" --group "Display" --key turnOffDisplayIdleTimeEnabled false
    kwriteconfig6 --file powermanagementprofilesrc --group "AC" --group "Display" --key dimDisplayIdleTimeEnabled false
    qdbus6 org.kde.KWin /org/kde/KWin reconfigure 2>/dev/null || true
    echo "KDE power management and lock screen disabled."

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
    echo "Web UI will be available at https://localhost:47990 after reboot."
    confirm_reboot
fi

# =============================================================
# STAGE 4 - falcond
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
                    set_stage 4
                    exit 1
                fi
                echo "Build succeeded after automatic hash fix!"
            else
                echo "Could not extract correct hash automatically."
                echo "Manual fix required - see ~/Downloads/falcond-build.log"
                set_stage 4
                exit 1
            fi
        else
            echo "Build failed for unknown reason."
            echo "Check the log: cat ~/Downloads/falcond-build.log"
            set_stage 4
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
    sudo systemctl enable falcond
    sudo systemctl start falcond || true
    
    set_stage 5
    echo ""
    echo "Stage 4 complete! No reboot needed, continuing to Stage 5..."
    echo ""
fi

# =============================================================
# STAGE 5 - Gaming Applications
# =============================================================

if [ "$STAGE" = "5" ]; then
    show_stage_summary 5

    if [ "$INTERACTIVE" = true ]; then
        if ! confirm "Run Stage 5 now?"; then
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

    set_stage 6
    remove_resume_service
    rm -f "$STAGE_FILE"

    echo ""
    echo "========================================================"
    echo " SETUP COMPLETE! (KDE Path)"
    echo ""
    echo " Your Fedora Gaming VM is fully configured."
    echo ""
    echo " Summary:"
    echo "  - CachyOS kernel ($(cat $HOME/.cachyos-install-variant 2>/dev/null || echo 'unknown'))"
    echo "  - NVIDIA GPU passthrough drivers"
    echo "  - Sunshine streaming"
    echo "  - KDE Plasma (Wayland)"
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
    echo "  - If Moonlight gives a 503 error, use restart-sunshine.bat"
    echo "========================================================"
fi
