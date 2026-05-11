#!/bin/bash
set -e

# === ROOT CHECK ===
if [ "$EUID" -eq 0 ]; then
    echo "ERROR: Do not run this script as root!"
    echo "Run as your normal user account with sudo available."
    exit 1
fi

# =============================================================
# MASTER SETUP SCRIPT - Fedora Gaming VM
# Combines scripts 1-5 with reboot persistence via systemd.
# Tracks completed stages in ~/.setup-stage
# Run once - it will guide you through all stages across
# multiple reboots until setup is complete.
# =============================================================

STAGE_FILE="$HOME/.setup-stage"
SCRIPT_PATH="$(realpath "$0")"
SERVICE_NAME="vm-setup-resume"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
CURRENT_USER="$USER"
CURRENT_HOME="$HOME"

# === HELPER FUNCTIONS ===

get_stage() {
    cat "$STAGE_FILE" 2>/dev/null || echo "0"
}

set_stage() {
    echo "$1" > "$STAGE_FILE"
}

confirm() {
    local MSG="$1"
    read -p "${MSG} (yes/no): " REPLY
    [ "$REPLY" = "yes" ]
}

confirm_reboot() {
    echo ""
    echo "--------------------------------------------------------"
    echo " A reboot is required before continuing to the next stage."
    echo "--------------------------------------------------------"
    if confirm "Reboot now?"; then
        echo "Rebooting..."
        sudo reboot
    else
        echo "Please reboot manually when ready, then re-run this script."
        exit 0
    fi
}

install_resume_service() {
    # Creates a systemd service that re-runs this script after reboot
    sudo tee "$SERVICE_FILE" > /dev/null << EOF
[Unit]
Description=VM Setup Resume Service
After=network.target graphical.target
After=display-manager.service

[Service]
Type=oneshot
User=${CURRENT_USER}
Environment=HOME=${CURRENT_HOME}
ExecStart=/bin/bash ${SCRIPT_PATH}
StandardInput=tty
TTYPath=/dev/tty1
StandardOutput=tty
StandardError=tty

[Install]
WantedBy=multi-user.target
EOF
    sudo systemctl daemon-reload
    sudo systemctl enable "$SERVICE_NAME"
}

remove_resume_service() {
    # Removes the systemd service once setup is complete
    if [ -f "$SERVICE_FILE" ]; then
        sudo systemctl disable "$SERVICE_NAME" 2>/dev/null || true
        sudo rm -f "$SERVICE_FILE"
        sudo systemctl daemon-reload
    fi
}

# === STAGE DISPLAY ===

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
            echo "  - Download the NVIDIA driver"
            echo "  - Prompt you to run the installer manually"
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

# First run - install resume service and start from stage 1
if [ "$STAGE" = "0" ]; then
    echo "========================================================"
    echo " Fedora Gaming VM - Master Setup Script"
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
    if ! confirm "Ready to begin setup?"; then
        echo "Exiting. Run this script again when ready."
        exit 0
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
    if ! confirm "Run Stage 1 now?"; then
        echo "Exiting. Run this script again when ready."
        exit 0
    fi

    echo ""
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

    # Save kernel selection for later stages
    echo "$KERNEL_PKG" > "$HOME/.cachyos-install-variant"

    sudo dnf upgrade --refresh -y
    sudo dnf upgrade -y

    sudo dnf install -y \
        https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
        https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

    sudo dnf install -y dnf-plugins-core
    sudo setsebool -P domain_kernel_load_modules on

    sudo dnf copr enable bieszczaders/kernel-cachyos
    sudo dnf copr enable bieszczaders/kernel-cachyos-addons

    sudo dnf install -y $KERNEL_PKG $KERNEL_DEVEL_PKG
    sudo dnf install -y --allowerasing cachyos-settings scx-manager scx-scheds-git scx-tools-git

    sudo dnf upgrade --refresh -y
    sudo dnf upgrade -y

    CACHY_VER=$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' $KERNEL_PKG | tail -1)
    sudo dracut -f --kver "$CACHY_VER"
    sudo grub2-mkconfig -o /boot/grub2/grub.cfg

    set_stage 2
    echo ""
    echo "Stage 1 complete! Kernel installed: $KERNEL_PKG"
    echo "Select the CachyOS kernel from GRUB after reboot."
    confirm_reboot
fi

# =============================================================
# STAGE 2 - NVIDIA Driver
# =============================================================

if [ "$STAGE" = "2" ]; then
    show_stage_summary 2

    # Verify CachyOS kernel
    if ! uname -r | grep -q "cachy"; then
        echo "ERROR: Not running on the CachyOS kernel!"
        echo "Current kernel: $(uname -r)"
        echo "Please reboot and select the CachyOS kernel from GRUB."
        exit 1
    fi
    echo "CachyOS kernel confirmed: $(uname -r)"

    if ! confirm "Run Stage 2 now?"; then
        echo "Exiting. Run this script again when ready."
        exit 0
    fi

    sudo dnf install -y kernel-devel kernel-headers gcc make dkms acpid \
        libglvnd-glx libglvnd-opengl libglvnd-devel pkgconfig libxcb egl-wayland

    cd ~/Downloads
    wget https://us.download.nvidia.com/XFree86/Linux-x86_64/595.71.05/NVIDIA-Linux-x86_64-595.71.05.run
    chmod +x NVIDIA-Linux-x86_64-595.71.05.run

    echo ""
    echo "========================================================"
    echo " Run the NVIDIA installer now:"
    echo "   sudo ~/Downloads/NVIDIA-Linux-x86_64-595.71.05.run"
    echo " Select NO to xconfig utility when prompted."
    echo "========================================================"
    read -p "Press Enter when the NVIDIA installer has finished..."

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
        echo "Please run the NVIDIA installer first."
        exit 1
    fi
    echo "CachyOS kernel and NVIDIA driver confirmed."

    if ! confirm "Run Stage 3 now?"; then
        echo "Exiting. Run this script again when ready."
        exit 0
    fi

    sudo dnf install -y python3-dnf-plugin-post-transaction-actions
    sudo dnf copr enable lizardbyte/beta
    sudo dnf install -y Sunshine

    sudo setcap cap_sys_admin+p $(readlink -f $(which sunshine))

    sudo tee /etc/dnf/plugins/post-transaction-actions.d/sunshine.action << 'EOF'
Sunshine:in:any:/usr/bin/sunshine:execute:sudo setcap cap_sys_admin+p $(readlink -f $(which sunshine))
EOF

    sudo usermod -aG input $USER
    sudo udevadm control --reload-rules && sudo udevadm trigger -s input
    sudo grubby --update-kernel=ALL --args="nvidia_drm.modeset=1"

    mkdir -p ~/.config/plasma-workspace/env
    tee ~/.config/plasma-workspace/env/kwin-sunshine.sh << 'EOF'
export KWIN_USE_OVERLAYS=0
EOF
    chmod +x ~/.config/plasma-workspace/env/kwin-sunshine.sh

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

    # Disable screen lock and power management
    # Prevents 503 errors by ensuring Sunshine always has
    # an active display to capture regardless of idle time
    kwriteconfig6 --file kscreenlockerrc --group Daemon --key Autolock false
    kwriteconfig6 --file kscreenlockerrc --group Daemon --key LockOnResume false
    kwriteconfig6 --file powermanagementprofilesrc --group "AC" --group "DPMSControl" --key idleTime 0
    kwriteconfig6 --file powermanagementprofilesrc --group "AC" --group "DPMSControl" --key lockBeforeSleep false
    kwriteconfig6 --file powermanagementprofilesrc --group "AC" --group "Display" --key turnOffDisplayIdleTimeEnabled false
    kwriteconfig6 --file powermanagementprofilesrc --group "AC" --group "Display" --key dimDisplayIdleTimeEnabled false
    qdbus6 org.kde.KWin /org/kde/KWin reconfigure 2>/dev/null || true

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

    if ! confirm "Run Stage 4 now?"; then
        echo "Exiting. Run this script again when ready."
        exit 0
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

    # Build with automatic hash mismatch fix
    if ! zig build -Doptimize=ReleaseFast 2>~/Downloads/falcond-build.log; then
        if grep -q "hash mismatch" ~/Downloads/falcond-build.log; then
            echo "Hash mismatch detected - attempting automatic fix..."

            # Extract the correct hash from the error message
            CORRECT_HASH=$(grep "but the fetched package has" ~/Downloads/falcond-build.log | \
                grep -o '[A-Za-z0-9_$-]\{40,\}' | tail -1)

            if [ -n "$CORRECT_HASH" ]; then
                echo "Correct hash found: $CORRECT_HASH"

                # Extract the old hash from build.zig.zon
                OLD_HASH=$(grep -o '[A-Za-z0-9_$-]\{40,\}' build.zig.zon | head -1)

                # Replace old hash with correct one
                sed -i "s/$OLD_HASH/$CORRECT_HASH/" build.zig.zon
                echo "Hash updated, retrying build..."

                # Second attempt with fixed hash
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
    sudo systemctl enable --now falcond

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

    if ! confirm "Run Stage 5 now?"; then
        echo "Exiting. Run this script again when ready."
        exit 0
    fi

    sudo dnf install -y flatpak
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

    sudo dnf install -y steam
    flatpak install -y flathub net.davidotek.pupgui2
    flatpak install -y flathub com.heroicgameslauncher.hgl
    sudo dnf install -y mangohud gamemode

    set_stage 6
    remove_resume_service
    rm -f "$STAGE_FILE"

    echo ""
    echo "========================================================"
    echo " SETUP COMPLETE!"
    echo ""
    echo " Your Fedora Gaming VM is fully configured."
    echo ""
    echo " Summary:"
    echo "  - CachyOS kernel ($(cat $HOME/.cachyos-install-variant 2>/dev/null || echo 'unknown'))"
    echo "  - NVIDIA GPU passthrough drivers"
    echo "  - Sunshine streaming (https://localhost:47990)"
    echo "  - falcond performance daemon"
    echo "  - Steam, ProtonUp-Qt, Heroic, MangoHud, Gamemode"
    echo ""
    echo " Tips:"
    echo "  - Run ProtonUp-Qt with Steam closed to install Proton-GE"
    echo "  - Steam launch options for best performance:"
    echo "    MANGOHUD=1 gamemoderun %command%"
    echo "  - Storage scripts (6-9) are available separately"
    echo "========================================================"
fi
