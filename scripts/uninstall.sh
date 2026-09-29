#!/bin/bash

# 1. Makesure running with sudo
if [ "$EUID" -ne 0 ]; then
    echo "❌ Error: Global uninstallation requires root privileges."
    echo "Please run this script with sudo: sudo ./scripts/uninstall.sh"
    exit 1
fi

echo "Uninstalling AutoClicker globally..."

# 2. Define path same with install.sh
LOCAL_BIN="/usr/local/bin/autoclicker"
DESKTOP_FILE="/usr/share/applications/autoclicker.desktop"
PIXMAP_FILE="/usr/share/pixmaps/autoclicker.png"
UDEV_RULE="/etc/udev/rules.d/99-autoclicker.rules"

# 3. Clean Binary
if [ -f "$LOCAL_BIN" ]; then
    rm -f "$LOCAL_BIN"
    echo "Removed binary: $LOCAL_BIN"
fi

# 4. Remove Desktop Entry
if [ -f "$DESKTOP_FILE" ]; then
    rm -f "$DESKTOP_FILE"
    echo "Removed desktop shortcut: $DESKTOP_FILE"
fi

# 5. Remove Icon
if [ -f "$PIXMAP_FILE" ]; then
    rm -f "$PIXMAP_FILE"
    echo "Removed icon: $PIXMAP_FILE"
fi

# 6. Delete udev configuration and reload rules
if [ -f "$UDEV_RULE" ]; then
    rm -f "$UDEV_RULE"
    echo "Removed udev rules: $UDEV_RULE"

    # Reload udev
    echo "Reloading udev permissions..."
    udevadm control --reload-rules
    udevadm trigger
fi

echo "✅ AutoClicker successfully uninstalled!"
