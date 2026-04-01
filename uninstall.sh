#!/bin/bash
set -e

OS_NAME=$(uname -s)
MAC_PLIST_TARGET="/Library/LaunchDaemons/com.deepcool.lm.plist"
INSTALL_BIN="/usr/local/bin/deepcool-lm"
INSTALL_LIBEXEC_DIR="/usr/local/libexec/deepcool-lm"

uninstall_linux() {
    if systemctl is-active --quiet lm360.service 2>/dev/null; then
        echo "🛑 Stopping old lm360 service..."
        systemctl stop lm360.service
    fi
    if systemctl is-enabled --quiet lm360.service 2>/dev/null; then
        systemctl disable lm360.service
    fi
    if [ -f /etc/systemd/system/lm360.service ]; then
        rm /etc/systemd/system/lm360.service
    fi
    if [ -f /usr/local/bin/lm360 ]; then
        rm /usr/local/bin/lm360
    fi

    if systemctl is-active --quiet deepcool-lm.service 2>/dev/null; then
        echo "🛑 Stopping service..."
        systemctl stop deepcool-lm.service
        echo "✓ Service stopped"
    fi

    if systemctl is-enabled --quiet deepcool-lm.service 2>/dev/null; then
        echo "🔓 Disabling service..."
        systemctl disable deepcool-lm.service
        echo "✓ Service disabled"
    fi

    if [ -f /etc/systemd/system/deepcool-lm.service ]; then
        echo "🗑️  Removing systemd service..."
        rm /etc/systemd/system/deepcool-lm.service
        systemctl daemon-reload
        echo "✓ Service removed"
    fi

    rm -f /var/run/lm360.sock /var/run/deepcool-lm.sock 2>/dev/null || true
}

uninstall_macos() {
    if [ -f "$MAC_PLIST_TARGET" ]; then
        echo "🛑 Unloading LaunchDaemon..."
        launchctl bootout system "$MAC_PLIST_TARGET" 2>/dev/null || true
        rm -f "$MAC_PLIST_TARGET"
        echo "✓ LaunchDaemon removed"
    fi

    rm -f /tmp/deepcool-lm.sock /private/tmp/deepcool-lm.sock 2>/dev/null || true

    if [ -d "$INSTALL_LIBEXEC_DIR" ]; then
        echo "🗑️  Removing macOS runtime..."
        rm -rf "$INSTALL_LIBEXEC_DIR"
        echo "✓ Runtime removed"
    fi
}

echo "=========================================="
echo "  Deepcool LM Series LCD Driver Uninstaller"
echo "=========================================="
echo ""

if [ "$EUID" -ne 0 ]; then
    echo "❌ Error: This script must be run as root"
    echo "   Please run: sudo ./uninstall.sh"
    exit 1
fi

case "$OS_NAME" in
    Linux)
        uninstall_linux
        ;;
    Darwin)
        uninstall_macos
        ;;
    *)
        echo "❌ Error: Unsupported OS: $OS_NAME"
        exit 1
        ;;
esac

if [ -f "$INSTALL_BIN" ]; then
    echo "🗑️  Removing CLI tool..."
    rm "$INSTALL_BIN"
    echo "✓ CLI tool removed"
fi

echo ""
echo "=========================================="
echo "  Uninstallation Complete!"
echo "=========================================="
echo ""
echo "All Deepcool LM series driver components have been removed."
echo "The display will return to default behavior or turn off."
echo ""
