# AutoClicker

![License](https://img.shields.io/badge/license-GPL--3.0-blue.svg)
![Platform](https://img.shields.io/badge/platform-Linux-green.svg)

A blazing fast, hardware-level AutoClicker interface built in native C++ and GTK3. 


---

## ⚠️ Requirements

This project is a userspace GUI. It **requires** the `RKKDR` (Kernel Driver) module to be loaded into your Linux kernel to function. The GUI communicates with the custom `/dev/rkkdr_mouse` hardware interface exposed by that driver.

### Dependencies (Arch Linux)
You will need GTK3 and standard C++ compilation tools:
```bash
sudo pacman -S gtk3 pkgconf base-devel
```

---

## Installation & Setup

To get started, clone the repository with its dependencies. Because the `RKKDR` kernel driver is included as a Git Submodule, use the `--recursive` flag:

```bash
git clone --recursive https://github.com/RiiK26/AutoClicker.git
cd AutoClicker
```

*(If you already cloned it without the flag, run `git submodule update --init --recursive` inside the folder).*

---

## Desktop Application Installation

If you want to install AutoClicker properly into your system's application menu (like a normal desktop app), you can use the provided install scripts. 

1. Ensure the `RKKDR` kernel module is loaded (you can run `./launcher.sh` once to do this automatically).
2. Run the installation script:
   ```bash
   ./scripts/install.sh
   ```
This will compile the app natively, generate a `.desktop` shortcut with a proper icon, and place the executable in your local user profile (`~/.local/share/`). **It does not require `sudo` to install!**

If you ever wish to uninstall it, simply run:
```bash
./scripts/uninstall.sh
```

---

## Usage

### The Easy Way (Launcher)
Simply run the included launcher script from your terminal or by double-clicking it on your desktop. It will automatically:
1. Compile the project
2. Check if the `RKKDR` kernel driver is loaded. If not, it will build the module and load it into your kernel.
   * **Note:** It will also automatically generate `MOK` (Machine Owner Key) signing keys for you on the fly if your system requires Secure Boot!
3. Launch the interface cleanly by using `pkexec` to present a native, graphical password prompt.

```bash
./launcher.sh
```

### The Manual Way
1. Compile the GUI natively:
   ```bash
   make
   ```
2. Ensure the `RKKDR` driver is compiled and loaded into your kernel (via the `RKKDR` directory).
3. Run the GUI manually (Requires `pkexec` or `sudo` to write to the kernel `/sys/` node and device files):
   ```bash
   pkexec env DISPLAY="$DISPLAY" XAUTHORITY="$XAUTHORITY" ./release/AutoClicker
   ```

### LICENSE
This project is licensed under the GPL-3.0 [LICENSE](License)