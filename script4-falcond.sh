#!/bin/bash
set -e

# =============================================================
# SCRIPT 4 OF 5 - falcond Performance Daemon
# Run this on the CachyOS kernel AFTER rebooting from script 3.
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

# === DEPENDENCIES ===
sudo dnf install -y zig git

# === CLONE OR UPDATE FALCOND ===
cd ~/Downloads
if [ -d "falcond" ]; then
    git -C falcond pull
else
    git clone https://git.pika-os.com/general-packages/falcond.git
fi

cd falcond/falcond
rm -rf ~/.cache/zig

# === BUILD WITH AUTOMATIC HASH MISMATCH FIX ===
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
                exit 1
            fi
            echo "Build succeeded after automatic hash fix!"
        else
            echo "Could not extract correct hash automatically."
            echo "Manual fix required - see ~/Downloads/falcond-build.log"
            exit 1
        fi
    else
        echo "Build failed for unknown reason."
        echo "Check the log: cat ~/Downloads/falcond-build.log"
        exit 1
    fi
fi

# === INSTALL BINARY AND SERVICE ===
sudo install -Dm755 zig-out/bin/falcond /usr/bin/falcond
sudo install -Dm644 debian/falcond.service /etc/systemd/system/falcond.service

# === INSTALL PROFILES ===
cd ~/Downloads
if [ -d "falcond-profiles" ]; then
    git -C falcond-profiles pull
else
    git clone https://github.com/PikaOS-Linux/falcond-profiles.git
fi

sudo mkdir -p /usr/share/falcond/profiles
sudo cp -r falcond-profiles/usr/share/falcond/* /usr/share/falcond/

# === ENABLE AND START ===
sudo systemctl daemon-reload
sudo systemctl enable --now falcond
sudo systemctl status falcond --no-pager

echo ""
echo "========================================================"
echo " SCRIPT 4 COMPLETE"
echo ""
echo " falcond is installed and running."
echo " Config auto-generated at /etc/falcond/config.conf"
echo " Check status: sudo systemctl status falcond"
echo "========================================================"
