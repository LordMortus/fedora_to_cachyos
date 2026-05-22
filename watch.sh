#!/bin/bash
# ================================================================
# watch.sh - Service Log Viewer
# Quick access to setup service logs during/after VM setup
# ================================================================

show_menu() {
    echo ""
    echo "========================================================"
    echo " VM Setup Log Viewer"
    echo "========================================================"
    echo ""
    echo " 1) First boot service    (vm-first-boot)"
    echo " 2) Setup resume service  (vm-setup-resume)"
    echo " 3) Both (interleaved)    (all setup units)"
    echo ""
    echo " Add --all to any choice to dump full log instead of following"
    echo " Example: ./watch.sh 1 --all"
    echo ""
    echo "========================================================"
    read -p " Choice [1/2/3]: " CHOICE
}

FOLLOW="-f"
if [[ "$*" == *"--all"* ]]; then
    FOLLOW="--no-pager"
fi

# If a number was passed as first arg, skip the menu
if [[ "$1" =~ ^[123]$ ]]; then
    CHOICE="$1"
else
    show_menu
fi

case "$CHOICE" in
    1)
        echo "Following vm-first-boot.service..."
        journalctl -u vm-first-boot.service $FOLLOW
        ;;
    2)
        echo "Following vm-setup-resume.service..."
        journalctl -u vm-setup-resume $FOLLOW
        ;;
    3)
        echo "Following all setup units..."
        journalctl -u vm-first-boot.service -u vm-setup-resume $FOLLOW
        ;;
    *)
        echo "Invalid choice."
        exit 1
        ;;
esac
