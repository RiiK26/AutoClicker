#!/bin/bash
# Move to the project root
cd "$(dirname "$0")/.."

if [ "$EUID" -ne 0 ]; then
    echo "❌ Error: Global installation requires root privileges."
    echo "Please run this script with sudo: sudo ./scripts/install.sh"
    exit 1
fi

echo "Installing AutoClicker globally..."

# 1. Pre-check: Ensure RKKDR driver is loaded
if ! lsmod | grep -q RKKDR; then
    # Try to load it if missing, silently
    modprobe RKKDR 2>/dev/null
fi

# 2. Compile the app natively
echo "Compiling AutoClicker..."
make || { echo "❌ Build failed"; exit 1; }

# 3. Create the installation directories
INSTALL_DIR="/usr/local/bin"
APPS_DIR="/usr/share/applications"
PIXMAPS_DIR="/usr/share/pixmaps"
UDEV_DIR="/etc/udev/rules.d"

# 4. Copy the necessary files
echo "Copying files..."
cp build/release/AutoClicker "$INSTALL_DIR/autoclicker"
cp image/AutoClick.png "$PIXMAPS_DIR/autoclicker.png"

# 4.5 Configure udev rules so the app can run without root!
# This solves all Wayland/pkexec/Polkit issues permanently.
echo "Configuring udev permissions..."
cat <<'EOF' > "$UDEV_DIR/99-autoclicker.rules"
# Allow read access to all input event devices for the hotkey listener
KERNEL=="event*", SUBSYSTEM=="input", MODE="0644"

# Allow read/write access to RKKDR module parameters
ACTION=="add", SUBSYSTEM=="module", KERNEL=="RKKDR", RUN+="/bin/chmod a+rw /sys/module/RKKDR/parameters/enable /sys/module/RKKDR/parameters/interval_ms /sys/module/RKKDR/parameters/hold_click"
EOF
udevadm control --reload-rules
udevadm trigger

# If the module is already loaded, apply permissions immediately
if [ -d "/sys/module/RKKDR/parameters" ]; then
    chmod a+rw /sys/module/RKKDR/parameters/enable /sys/module/RKKDR/parameters/interval_ms /sys/module/RKKDR/parameters/hold_click 2>/dev/null || true
fi
chmod a+r /dev/input/event* 2>/dev/null || true

# 5. Generate the Desktop Entry (.desktop file)
DESKTOP_FILE="$APPS_DIR/autoclicker.desktop"
echo "Creating desktop shortcut at $DESKTOP_FILE..."

cat <<EOF > "$DESKTOP_FILE"
[Desktop Entry]
Version=1.0
Type=Application
Name=AutoClicker
Comment=Hardware-level AutoClicker GUI
Exec=/usr/local/bin/autoclicker
Icon=autoclicker
Terminal=false
Categories=Utility;
EOF

chmod +x "$DESKTOP_FILE"

echo "✅ AutoClicker successfully installed globally!"
echo "You can now launch it directly from your desktop or application menu without needing root."
