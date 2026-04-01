#!/bin/bash
set -e

OS_NAME=$(uname -s)
REPO_URL="https://raw.githubusercontent.com/daedlock/deepcool-lm/main"
TEMP_DIR=$(mktemp -d)
FILE_SOURCE="."
MAC_PLIST="com.deepcool.lm.plist"
MAC_PLIST_TARGET="/Library/LaunchDaemons/${MAC_PLIST}"
INSTALL_BIN="/usr/local/bin/deepcool-lm"
INSTALL_LIBEXEC_DIR="/usr/local/libexec/deepcool-lm"
INSTALL_APP="$INSTALL_LIBEXEC_DIR/deepcool-lm.py"
INSTALL_VENV="$INSTALL_LIBEXEC_DIR/.venv"

cleanup() {
    rm -rf "$TEMP_DIR"
}

confirm_continue() {
    local prompt=$1
    read -p "$prompt (y/N) " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]]
}

download_file() {
    local file=$1
    echo "📥 Downloading $file..."
    curl -fsSL "$REPO_URL/$file" -o "$TEMP_DIR/$file"
}

prepare_sources() {
    local need_download=0
    local file

    for file in "$@"; do
        if [ ! -f "$file" ]; then
            need_download=1
            break
        fi
    done

    if [ "$need_download" -eq 1 ]; then
        echo "📥 Downloading driver files from GitHub..."
        FILE_SOURCE="$TEMP_DIR"
        for file in "$@"; do
            download_file "$file"
        done
    fi
}

linux_device_present() {
    command -v lsusb >/dev/null 2>&1 && lsusb | grep -q "3633:0026"
}

macos_device_present() {
    ioreg -p IOUSB -l 2>/dev/null | grep -qi '"idVendor" = 0x3633'
}

check_macos_python_modules() {
    local python_cmd=${1:-python3}
    local missing=()

    "$python_cmd" -c "import usb" >/dev/null 2>&1 || missing+=("pyusb")
    "$python_cmd" -c "import psutil" >/dev/null 2>&1 || missing+=("psutil")
    "$python_cmd" -c "from PIL import Image" >/dev/null 2>&1 || missing+=("pillow")

    if [ ${#missing[@]} -gt 0 ]; then
        echo "⚠️  Missing Python modules: ${missing[*]}"
        echo "   Install them with: $python_cmd -m pip install pyusb psutil pillow"
        echo "   libusb is also required. On Homebrew: brew install libusb"
        confirm_continue "   Continue anyway?" || exit 1
    fi
}

get_macos_python() {
    local candidate

    for candidate in /opt/homebrew/bin/python3 /usr/local/bin/python3; do
        if [ -x "$candidate" ]; then
            echo "$candidate"
            return 0
        fi
    done

    command -v python3 2>/dev/null || true
}

install_macos_runtime() {
    local python_cmd=$1

    echo "📦 Creating isolated Python runtime..."
    mkdir -p "$INSTALL_LIBEXEC_DIR"
    rm -rf "$INSTALL_VENV"
    "$python_cmd" -m venv "$INSTALL_VENV"
    "$INSTALL_VENV/bin/python" -m pip install --upgrade pip >/dev/null
    "$INSTALL_VENV/bin/python" -m pip install pyusb psutil pillow

    cp "$FILE_SOURCE/deepcool-lm" "$INSTALL_APP"
    chmod 755 "$INSTALL_APP"

    cat > "$INSTALL_BIN" <<EOF
#!/bin/bash
exec "$INSTALL_VENV/bin/python" "$INSTALL_APP" "\$@"
EOF
    chmod 755 "$INSTALL_BIN"

    echo "✓ Installed launcher to $INSTALL_BIN"
    echo "✓ Runtime created at $INSTALL_VENV"
}

install_linux() {
    prepare_sources deepcool-lm deepcool-lm.service

    echo "🔍 Checking for lm_sensors..."
    if ! systemctl is-enabled --quiet lm_sensors.service 2>/dev/null; then
        echo "⚠️  Warning: lm_sensors service not found or not enabled"
        echo "   Temperature monitoring requires lm_sensors"
        echo "   - Arch: sudo pacman -S lm_sensors && sudo sensors-detect"
        echo "   - Ubuntu: sudo apt install lm-sensors && sudo sensors-detect"
        echo ""
        confirm_continue "   Continue anyway?" || exit 1
    else
        echo "✓ lm_sensors service found"
    fi

    echo "🔍 Checking for Deepcool LM series device..."
    if ! linux_device_present; then
        echo "⚠️  Warning: Deepcool LM series device not detected (VID:PID 3633:0026)"
        echo "   Make sure your LM series cooler is plugged in (tested: LM360)"
        confirm_continue "   Continue anyway?" || exit 1
    else
        echo "✓ Deepcool LM series device detected"
    fi

    if systemctl is-active --quiet lm360.service 2>/dev/null; then
        echo "🛑 Stopping old lm360 service..."
        systemctl stop lm360.service
        systemctl disable lm360.service 2>/dev/null || true
    fi

    if systemctl is-active --quiet deepcool-lm.service 2>/dev/null; then
        echo "🛑 Stopping existing service..."
        systemctl stop deepcool-lm.service
    fi

    echo "📦 Installing deepcool-lm CLI tool..."
    cp "$FILE_SOURCE/deepcool-lm" "$INSTALL_BIN"
    chmod +x "$INSTALL_BIN"
    echo "✓ Installed to $INSTALL_BIN"

    echo "📦 Installing systemd service..."
    cp "$FILE_SOURCE/deepcool-lm.service" /etc/systemd/system/deepcool-lm.service
    systemctl daemon-reload
    echo "✓ Service installed"

    echo ""
    read -p "Enable service to start on boot? (Y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        systemctl enable deepcool-lm.service
        echo "✓ Service enabled for startup"
    fi

    echo ""
    read -p "Start service now? (Y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        systemctl start deepcool-lm.service
        sleep 1
        if systemctl is-active --quiet deepcool-lm.service; then
            echo "✓ Service started successfully"
        else
            echo "❌ Service failed to start. Check logs with: journalctl -u deepcool-lm -n 50"
        fi
    fi

    echo ""
    echo "Usage:"
    echo "  Start service:     sudo systemctl start deepcool-lm"
    echo "  Stop service:      sudo systemctl stop deepcool-lm"
    echo "  Service status:    sudo systemctl status deepcool-lm"
    echo "  View logs:         sudo journalctl -u deepcool-lm -f"
}

install_macos() {
    prepare_sources deepcool-lm "$MAC_PLIST"

    local python_cmd

    python_cmd=$(get_macos_python)
    if [ -z "$python_cmd" ] || [ ! -x "$python_cmd" ]; then
        echo "❌ Error: python3 is required on macOS"
        echo "   Install it with Homebrew: brew install python"
        exit 1
    fi

    echo "✓ Using Python: $python_cmd"

    echo "🔍 Checking Python dependencies..."
    check_macos_python_modules "$python_cmd"

    echo "🔍 Checking for Deepcool LM series device..."
    if ! macos_device_present; then
        echo "⚠️  Warning: Deepcool LM series device not detected in IOUSBRegistry"
        echo "   Verify the cooler appears in System Information > USB"
        confirm_continue "   Continue anyway?" || exit 1
    else
        echo "✓ Deepcool LM series device detected"
    fi

    install_macos_runtime "$python_cmd"

    echo ""
    read -p "Install LaunchDaemon for automatic startup? (Y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        mkdir -p /Library/LaunchDaemons
        cp "$FILE_SOURCE/$MAC_PLIST" "$MAC_PLIST_TARGET"
        chmod 644 "$MAC_PLIST_TARGET"
        chown root:wheel "$MAC_PLIST_TARGET" 2>/dev/null || true
        echo "✓ LaunchDaemon installed at $MAC_PLIST_TARGET"

        echo ""
        read -p "Load LaunchDaemon now? (Y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            launchctl bootout system "$MAC_PLIST_TARGET" 2>/dev/null || true
            launchctl bootstrap system "$MAC_PLIST_TARGET"
            launchctl enable system/com.deepcool.lm 2>/dev/null || true
            launchctl kickstart -k system/com.deepcool.lm
            sleep 1
            if launchctl print system/com.deepcool.lm >/dev/null 2>&1; then
                echo "✓ LaunchDaemon loaded successfully"
            else
                echo "⚠️  LaunchDaemon was installed but may not be running yet"
                echo "   Check logs in /var/log/deepcool-lm.log and /var/log/deepcool-lm.err"
            fi
        fi
    fi

    echo ""
    echo "Usage:"
    echo "  Start now:         sudo launchctl bootstrap system $MAC_PLIST_TARGET"
    echo "  Restart:           sudo launchctl kickstart -k system/com.deepcool.lm"
    echo "  Stop:              sudo launchctl bootout system $MAC_PLIST_TARGET"
    echo "  View logs:         sudo tail -f /var/log/deepcool-lm.log"
    echo "  View errors:       sudo tail -f /var/log/deepcool-lm.err"
}

trap cleanup EXIT

echo "=========================================="
echo "  Deepcool LM Series LCD Driver Installer"
echo "=========================================="
echo ""

if [ "$EUID" -ne 0 ]; then
    echo "❌ Error: This script must be run as root"
    echo "   Please run: sudo ./install.sh"
    exit 1
fi

case "$OS_NAME" in
    Linux)
        install_linux
        ;;
    Darwin)
        install_macos
        ;;
    *)
        echo "❌ Error: Unsupported OS: $OS_NAME"
        exit 1
        ;;
esac

echo ""
echo "CLI Commands:"
echo "  System monitor:    sudo deepcool-lm monitor"
echo "  Display image:     sudo deepcool-lm image /path/to/image.jpg"
echo "  Display color:     sudo deepcool-lm solid --color 255 0 0"
echo "  Brightness up:     sudo deepcool-lm brightness up"
echo "  Brightness down:   sudo deepcool-lm brightness down"
echo ""
echo "Run 'deepcool-lm --help' for more options"
echo ""
echo "=========================================="
echo "  Installation Complete!"
echo "=========================================="
echo ""
