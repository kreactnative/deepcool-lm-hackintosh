# Deepcool LM Series LCD Driver for Linux and macOS

A cross-platform driver for Deepcool LM series AIO coolers with LCD displays (320x240). It supports Linux and macOS, with a polished system monitoring interface, real-time CPU and GPU temperature display, CPU usage tracking, and custom image support.

![LM360 Display](https://img.shields.io/badge/Resolution-320x240-blue) ![License](https://img.shields.io/badge/License-MIT-green)

![Deepcool LM360 Display Preview](lm360.png)

> **Note**: This driver is designed for Deepcool LM series coolers. Currently tested and confirmed working on **LM360** only. Other LM series models (LM240, LM280, etc.) may work but have not been tested. Contributions and testing reports are welcome!

## Features

- 🎨 **Polished System Monitor** - Beautiful dual-panel interface with CPU and GPU stats
- 🌡️ **Temperature Monitoring** - Real-time CPU and GPU temperature display with color gradients
- 📊 **Usage Tracking** - CPU usage percentage with animated progress bars
- ⚡ **CPU Frequency** - Current CPU frequency display
- 🖼️ **Custom Images** - Display any image on the LCD (auto-resized to 320x240)
- 🔆 **Brightness Control** - Adjust display brightness
- 🔄 **Persistent State** - Service maintains display mode (monitor/image/color)
- 🎯 **Clean UI** - Modern design with rounded borders, icons, and smooth progress bars
- 🔌 **IPC Communication** - CLI communicates with running service without conflicts

## Display Preview

The monitor interface features:
- **CPU Section** (Top): Temperature, usage %, frequency, and usage progress bar
- **GPU Section** (Bottom): Temperature with visual temperature gradient
- **Color-coded Temps**: Cool blue (< 40°C) → Green (< 60°C) → Yellow (< 75°C) → Orange (< 85°C) → Red (85°C+)
- **Rounded Containers**: Modern card-based layout with 8px rounded corners
- **Icons**: Visual indicators (⚙ for CPU, ▣ for GPU)

## Installation

### Prerequisites

#### Linux
- **libusb**: USB device communication library
- **lm_sensors**: Temperature monitoring
- **Python 3.7+** with `pyusb`, `psutil`, `pillow` modules

#### macOS
- **Homebrew**: Package manager
- **Python 3.8+**: Available via Homebrew
- **libusb**: USB device communication library
- Optional: **powermetrics** (usually pre-installed) for temperature monitoring

### Step-by-Step Installation

#### Option 1: Linux - Arch Linux (AUR)

This is the easiest method on Arch Linux:

```bash
yay -S deepcool-lm
```

The service will automatically start if your device is connected!

#### Option 2: Linux & macOS - Automated Script

For other Linux distributions or macOS, use the automated installer:

**Method A: Direct download and run**
```bash
curl -fsSL https://raw.githubusercontent.com/daedlock/deepcool-lm/main/install.sh | sudo bash
```

**Method B: Download, review, then run**
```bash
curl -O https://raw.githubusercontent.com/daedlock/deepcool-lm/main/install.sh
chmod +x install.sh
sudo ./install.sh
```

#### Option 3: Manual Installation (Linux)

**1. Install Dependencies**

For Arch Linux:
```bash
sudo pacman -S lm_sensors python-pyusb python-psutil python-pillow libusb
```

For Ubuntu/Debian:
```bash
sudo apt install lm-sensors python3-usb python3-psutil python3-pil libusb-1.0-0
```

For Fedora:
```bash
sudo dnf install lm_sensors python3-pyusb python3-psutil python3-pillow libusb
```

**2. Configure Temperature Monitoring**

```bash
sudo sensors-detect  # Answer YES to save configuration
sudo systemctl enable --now lm_sensors
```

**3. Download and Install**

```bash
git clone https://github.com/daedlock/deepcool-lm.git
cd deepcool-lm
chmod +x deepcool-lm deepcool-lm.install
sudo ./deepcool-lm.install
```

**4. Enable the Service**

```bash
sudo systemctl enable deepcool-lm
sudo systemctl start deepcool-lm
```

#### Option 4: Manual Installation (macOS)

**1. Install Runtime Dependencies**

```bash
brew install python libusb
```

**2. Download and Install**

```bash
git clone https://github.com/daedlock/deepcool-lm.git
cd deepcool-lm
curl -O https://raw.githubusercontent.com/daedlock/deepcool-lm/main/install.sh
chmod +x install.sh
sudo ./install.sh
```

The installer will:
- Create an isolated Python virtual environment at `/usr/local/libexec/deepcool-lm/.venv`
- Install `pyusb`, `psutil`, and `pillow` into the venv
- Install the CLI launcher at `/usr/local/bin/deepcool-lm`
- Optionally install a LaunchDaemon for automatic startup

**3. Enable Automatic Startup (Optional)**

If you didn't enable it during installation:

```bash
launchctl bootstrap system /Library/LaunchDaemons/com.deepcool.lm.plist
launchctl enable system/com.deepcool.lm
```

## Post-Installation Verification

### Linux

Check service status:
```bash
sudo systemctl status deepcool-lm
```

View logs:
```bash
sudo journalctl -u deepcool-lm -f
```

### macOS

Check LaunchDaemon status:
```bash
launchctl print system/com.deepcool.lm
```

View logs:
```bash
sudo tail -f /var/log/deepcool-lm.log
sudo tail -f /var/log/deepcool-lm.err
```

## Usage

Once installed, use these commands to control the display:

```bash
# Start system monitoring mode
sudo deepcool-lm monitor

# Display a custom image (auto-resized to 320x240)
sudo deepcool-lm image /path/to/image.jpg

# Display solid color (RGB format)
sudo deepcool-lm solid --color 255 0 0

# Adjust brightness
sudo deepcool-lm brightness up
sudo deepcool-lm brightness down

# Show all available commands
deepcool-lm --help
```

## Troubleshooting

### Device Not Detected

**Linux**: Verify the Deepcool LM device appears:
```bash
lsusb | grep 3633
```

**macOS**: Check System Information > USB for the Deepcool device

### Temperature Shows 0°

**macOS**: This typically means `powermetrics` cannot read your sensors. The display will still work but won't show accurate temperatures. Check logs for details.

**Linux**: Ensure `lm_sensors` is properly configured:
```bash
sudo systemctl status lm_sensors
sensors
```

### Service Won't Start

**Linux**: Check logs for error messages:
```bash
sudo journalctl -u deepcool-lm -n 50
```

**macOS**: Check the log files:
```bash
sudo tail -20 /var/log/deepcool-lm.log
sudo tail -20 /var/log/deepcool-lm.err
```

## Usage

### Background Service (Recommended)

#### Linux systemd

The service runs the system monitor automatically in the background:

```bash
# Start the service
sudo systemctl start deepcool-lm

# Enable on boot
sudo systemctl enable deepcool-lm

# Check status
sudo systemctl status deepcool-lm

# View logs
sudo journalctl -u deepcool-lm -f

# Stop the service
sudo systemctl stop deepcool-lm
```

#### macOS launchd

If you install the LaunchDaemon, it runs the monitor in the background as root:

```bash
# Load the LaunchDaemon now
sudo launchctl bootstrap system /Library/LaunchDaemons/com.deepcool.lm.plist

# Restart the daemon
sudo launchctl kickstart -k system/com.deepcool.lm

# Stop the daemon
sudo launchctl bootout system /Library/LaunchDaemons/com.deepcool.lm.plist

# View logs
sudo tail -f /var/log/deepcool-lm.log
sudo tail -f /var/log/deepcool-lm.err
```

### CLI Commands

The `deepcool-lm` command provides various functions. When the service is running, commands communicate via IPC without conflicts:

#### System Monitor
```bash
# Start monitoring (when service is not running)
sudo deepcool-lm monitor

# Switch back to monitoring mode (when service is running)
sudo deepcool-lm monitor
```

#### Display Custom Image
```bash
# Display any image (will be resized to 320x240)
# Image persists until you switch modes
sudo deepcool-lm image /path/to/photo.jpg
sudo deepcool-lm image ~/wallpaper.png
```

#### Display Solid Color
```bash
# Black screen
sudo deepcool-lm solid --color 0 0 0

# Red screen
sudo deepcool-lm solid --color 255 0 0

# Custom RGB color
sudo deepcool-lm solid --color 100 150 200
```

#### Brightness Control
```bash
# Increase brightness
sudo deepcool-lm brightness up

# Decrease brightness
sudo deepcool-lm brightness down
```

#### Show Help
```bash
deepcool-lm --help
```

### Usage Examples

**Typical workflow:**
```bash
# Service is running showing CPU/GPU monitoring

# Display a custom image
sudo deepcool-lm image ~/my-image.jpg
# Image stays on screen

# Switch back to monitoring
sudo deepcool-lm monitor
# Back to CPU/GPU stats

# Adjust brightness while monitoring
sudo deepcool-lm brightness up
```

## Uninstallation

```bash
sudo ./uninstall.sh
```

This will:
- Stop and disable the background service
- Remove the service file
- Remove the CLI tool
- Clean up socket files

## Technical Details

### Compatibility
- **Tested Models**: Deepcool LM360
- **Likely Compatible**: Other LM series models (LM240, LM280, etc.) with USB VID:PID `3633:0026`
- **Status**: Untested on other LM series models - please report compatibility!

### Device Information
- **Vendor ID**: `0x3633`
- **Product ID**: `0x0026`
- **Display**: 320x240 RGB565
- **Protocol**: USB Bulk Transfer
- **Endpoint**: `0x01` (OUT)

### Frame Format
- **Header**: 13 bytes (`aa 08 00 00 01 00 58 02 00 2c 01 bc 11`)
- **Framebuffer**: 153,600 bytes (320 × 240 × 2)
- **Pixel Format**: RGB565 little-endian

### IPC Communication
- **Linux socket**: `/var/run/deepcool-lm.sock`
- **macOS socket**: `/tmp/deepcool-lm.sock`
- **Protocol**: Unix domain socket with JSON commands
- **Supported actions**: monitor, image, solid, brightness_up, brightness_down

### Temperature Sources
- **Linux CPU**: `coretemp` sensor (first core)
- **Linux GPU**: `nvme` sensor (if available)
- **macOS CPU/GPU**: `powermetrics --samplers smc -n 1 --format text` (best effort)

On Linux the driver uses `psutil.sensors_temperatures()` to read temperatures. You can check available sensors with:

```bash
sensors
```

## Troubleshooting

### Device Not Found
```bash
# Linux: check if device is detected
lsusb | grep 3633

# Should show: Bus XXX Device XXX: ID 3633:0026

# macOS: check USB registry
ioreg -p IOUSB -l | grep 3633
```

### Permission Denied
Make sure you're running with `sudo`:
```bash
sudo deepcool-lm monitor
```

### Service Won't Start
Check logs for errors:
```bash
# Linux
sudo journalctl -u deepcool-lm -n 50

# macOS
sudo tail -n 50 /var/log/deepcool-lm.err
```

### Screen Goes Black When CLI Stops
This is expected behavior when running CLI directly. Use the background service for persistent display:
```bash
# Linux
sudo systemctl start deepcool-lm
sudo systemctl enable deepcool-lm  # Start on boot

# macOS
sudo launchctl bootstrap system /Library/LaunchDaemons/com.deepcool.lm.plist
```

### Missing Temperature Sensors
If temps show as 0°C, check available sensors:
```bash
# Linux
sensors

# macOS
sudo powermetrics --samplers smc -n 1 --format text
```

On Linux you may need to load kernel modules:
```bash
sudo modprobe coretemp  # For Intel CPUs
```

## Development

### Project Structure
```
coolmaster-driver/
├── deepcool-lm              # Main CLI tool (standalone executable)
├── deepcool-lm.service      # Systemd service file
├── com.deepcool.lm.plist    # macOS launchd service file
├── install.sh               # Installation script
├── uninstall.sh             # Uninstallation script
├── PKGBUILD                 # Arch Linux package build
├── deepcool-lm-driver.install # AUR install hooks
└── README.md                # This file
```

### Building Custom Layouts

The `render_monitor_display()` function in `deepcool-lm` can be customized to create different layouts. Key functions:

- `draw_rounded_rect()` - Draw rounded rectangles
- `get_temp_color()` - Get color based on temperature
- `rgb_to_framebuffer()` - Convert PIL image to RGB565

Example of adding a custom element:
```python
# In render_monitor_display()
draw.text((160, 120), "Custom Text", fill=(255, 255, 255), font=fonts['small'])
```

## Credits

This driver was developed through reverse engineering the USB protocol used by the official Windows software.

## License

MIT License - Feel free to use and modify

## Contributing

Contributions are welcome! Please feel free to submit pull requests or open issues for bugs and feature requests.

## Changelog

### v1.0.0
- Initial release
- System monitoring with CPU/GPU temperature
- Custom image display with persistent state
- Solid color display
- Brightness control
- IPC communication for conflict-free CLI usage
- Systemd service integration
- Polished UI with rounded borders and progress bars
