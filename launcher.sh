#!/bin/bash
# Move to the project directory no matter where this script is called from
cd "$(dirname "$0")"

# 1. Make sure the script run from source tree
if [ ! -f "Makefile" ] || [ ! -d "src" ]; then
    echo "❌ Error: Script just run in folder source."
    exit 1
fi

echo "--- Development Source Tree Mode ---"

# 2. Map binary path
RELEASE_DIR="build/release"
BINARY="$PWD/$RELEASE_DIR/AutoClicker"

# 3. Check autoclicker binary
if [ ! -f "$BINARY" ]; then
    echo "Binary not found, compiling GUI..."
    make
else
    echo "✅ Skip make. Binary already at $BINARY"
fi

# 4. Check and load the Kernel Module
if ! lsmod | grep -q RKKDR; then
    echo "Loading kernel module RKKDR..."
    if [ -f "RKKDR/Makefile" ]; then
        KERNEL_DIR="RKKDR"
    elif [ -f "../KernelDriver/Makefile" ]; then
        KERNEL_DIR="../KernelDriver"
    else
        echo "❌ Error: RKKDR kernel driver source not found."
        exit 1
    fi

    sudo make -C "$KERNEL_DIR" load
fi

echo "Launching AutoClicker..."

# 5. Run only not install
PARAM_DIR="/sys/module/RKKDR/parameters"
if [ -w "$PARAM_DIR/enable" ] && \
   [ -w "$PARAM_DIR/interval_ms" ] && \
   [ -w "$PARAM_DIR/hold_click" ]; then
    "$BINARY"
else
    echo "⚠️ RKKDR parameter permissions are not ready. Request access root..."
    xhost +si:localuser:root > /dev/null 2>&1
    pkexec env DISPLAY="$DISPLAY" XAUTHORITY="$XAUTHORITY" "$BINARY" > gui_error.log 2>&1
fi
