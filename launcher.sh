#!/bin/bash
# Move to the project directory no matter where this script is called from
cd "$(dirname "$0")"

# 1. Check if we are running from a source tree or an installation
if [ -f "Makefile" ] && [ -d "release" ]; then
    # --- Source Tree Mode ---
    
    # Compile the GUI natively
    make
    
    # Check and load the Kernel Module if it's not already loaded
    if ! lsmod | grep -q RKKDR; then
        echo "Loading kernel module RKKDR..."
        if [ -f "RKKDR/Makefile" ]; then
            KERNEL_DIR="RKKDR"
        elif [ -f "../KernelDriver/Makefile" ]; then
            KERNEL_DIR="../KernelDriver"
        else
            echo "Error: RKKDR kernel driver source not found."
            exit 1
        fi
        make -C "$KERNEL_DIR" load
    fi
    
    RELEASE_DIR="release"
    BINARY="$PWD/$RELEASE_DIR/AutoClicker"
else
    # --- Installed Mode ---
    BINARY="$PWD/AutoClicker"
    
    # For installed mode, we just verify the module is already loaded
    if ! lsmod | grep -q RKKDR; then
        echo "Error: RKKDR kernel driver is not loaded!"
        echo "Please ensure the RKKDR kernel module is loaded before running the AutoClicker app."
        exit 1
    fi
fi

# 2. Allow root to access the X11 display
xhost +si:localuser:root > /dev/null 2>&1

# 3. Launch the GUI
pkexec env DISPLAY="$DISPLAY" XAUTHORITY="$XAUTHORITY" "$BINARY" > gui_error.log 2>&1