# Morse Micro HaLow Driver for Ubuntu/Tachyon

This repository contains the Morse Micro HaLow (802.11ah) USB WiFi driver, firmware, and tools ported from OpenWrt for Ubuntu 24.04 on ARM64 (Tachyon/Particle platform).

## Quick Start

```bash
# 1. Install build dependencies (Ubuntu 22.04+ x86_64 host)
sudo dpkg --add-architecture arm64
sudo apt-get update
sudo apt-get install -y gcc-aarch64-linux-gnu g++-aarch64-linux-gnu \
    make flex bison bc libssl-dev pkg-config \
    libnl-3-dev:arm64 libnl-genl-3-dev:arm64 libssl-dev:arm64

# 2. Extract kernel headers
cd kernel-headers
mkdir -p extracted
dpkg -x linux-particle-headers-*.deb extracted/
dpkg -x linux-headers-*-particle_*.deb extracted/
cd ..

# 3. Build everything
make

# 4. Assemble overlay for deployment
make overlay
```

See [Build Host Setup](#build-host-setup) for detailed requirements.

---

## Overview

| Component | Version | Upstream Repository |
|-----------|---------|---------------------|
| **morse_driver** | 1.16.4 | https://github.com/MorseMicro/morse_driver |
| **morse_cli** | 1.16.4 | https://github.com/MorseMicro/morse_cli |
| **hostap (wpa_supplicant_s1g)** | 1.16.4 | https://github.com/MorseMicro/hostap |
| **morse-firmware** | 1.16.4 | https://github.com/MorseMicro/morse-firmware |
| **morse-feed (OpenWrt)** | - | https://github.com/MorseMicro/morse-feed |

All components are sourced from Morse Micro's official GitHub repositories via their OpenWrt feed.

### What This Repository Provides

This repository adapts the upstream Morse Micro components for Ubuntu/Tachyon by:
- Applying OpenWrt patches from `morse-feed` for API compatibility
- Adding fixes for GCC 13+ and kernel 6.8
- Providing a standalone Makefile for cross-compilation (no OpenWrt build system required)
- Including Particle kernel headers for building against the target kernel
- Packaging everything into a Tachyon overlay for easy deployment

### Target Platform

- **OS**: Ubuntu 24.04 (Tachyon)
- **Architecture**: ARM64 (Qualcomm QCM6490)
- **Kernel**: 6.8.0-1056-particle

### Supported Hardware

| Property | Value |
|----------|-------|
| USB Vendor ID | `0x325b` (Morse Micro) |
| USB Product ID | `0x8100` (MM810X series) |
| Chipsets | MM6108, MM8108B2 |

---

## Repository Structure

```
morse-ubuntu/
├── driver/
│   ├── Makefile.ubuntu              # Cross-compilation makefile
│   └── morse_driver-1.16.4/         # Driver source with patches applied
│       ├── morse.ko                 # Main driver module (after build)
│       └── dot11ah/dot11ah.ko       # 802.11ah MAC layer module
│
├── firmware/                        # 27 firmware files
│   ├── mm6108.bin                   # MM6108 chip firmware
│   ├── mm6108-tlm.bin               # MM6108 thin LMAC firmware
│   ├── mm8108b2-rl.bin              # MM8108B2 chip firmware
│   ├── mm8108b2-tlm-rl.bin          # MM8108B2 thin LMAC firmware
│   ├── mm8108b2-flm-rl.bin          # MM8108B2 full LMAC firmware
│   └── bcf_*.bin                    # Board configuration files (22 files)
│
├── tools/
│   ├── morsecli/                    # morse_cli source and build
│   └── wpa_supplicant_s1g/          # S1G-enabled wpa_supplicant source
│       ├── wpa_supplicant/          # Supplicant source (station mode)
│       └── hostapd/                 # AP mode source (optional)
│
├── kernel-headers/                  # Particle kernel headers
│   ├── linux-headers-*.deb          # Kernel headers package
│   ├── linux-particle-headers-*.deb # Common kernel headers
│   └── extracted/                   # Extracted headers (gitignored, see setup)
│
├── overlay/
│   └── add-morse-halow/             # Tachyon overlay (ready to deploy)
│
└── patches/                         # OpenWrt patches (already applied)
```

---

## Components Detail

### 1. Driver Source (`driver/morse_driver-1.16.4/`)

The driver source is Morse Micro's official v1.16.4 release with modifications for Ubuntu/kernel 6.8 compatibility. See [Modifications from Upstream](#modifications-from-upstream) for complete details.

**Output modules:**
- `morse.ko` - Main driver (~24MB with debug symbols)
- `dot11ah.ko` - 802.11ah MAC layer (~2.5MB with debug symbols)

### 2. Kernel Headers (`kernel-headers/`)

The Particle kernel headers are required for cross-compiling the driver. These must match the target device's kernel version exactly.

**Required packages:**
- `linux-headers-6.8.0-1056-particle_6.8.0-1056.57+particle4_arm64.deb`
- `linux-particle-headers-6.8.0-1056_6.8.0-1056.57+particle4_all.deb`

> **Note:** The extracted headers are not included in the repository. See [Kernel Header Setup](#kernel-header-setup) below for instructions.

### 3. Firmware (`firmware/`)

27 firmware files supporting various Morse Micro chipsets and board configurations:

| Type | Files | Description |
|------|-------|-------------|
| Chip firmware | 5 | Core firmware for MM6108/MM8108B2 |
| Board configs | 22 | Configuration for specific modules (HM593, HM677, etc.) |

The `bcf_default.bin` symlink points to `bcf_failsafe.bin` for generic operation.

### 4. morse_cli (`tools/morsecli/`)

Command-line interface for driver configuration and diagnostics.

**Key commands:**
```bash
morse_cli version          # Show version info
morse_cli channel          # Get/set channel
morse_cli stats            # Show statistics
morse_cli country          # Get/set country code
```

### 5. wpa_supplicant_s1g (`tools/wpa_supplicant_s1g/`)

Morse Micro's fork of wpa_supplicant with 802.11ah Sub-1GHz (S1G) support.

**Binaries produced:**
- `wpa_supplicant_s1g` - WPA supplicant daemon
- `wpa_cli_s1g` - Command-line interface
- `hostapd_s1g` - Access point daemon (optional)

**Key features:**
- WPA3-SAE authentication support
- S1G channel handling
- H2E (Hash-to-Element) SAE mode

---

## Kernel Header Setup

Before building the driver, you must extract the kernel headers. The `.deb` packages are included in the repository, but the extracted files are not (to reduce repository size).

### Option 1: Download from Particle APT Repository

If you need a different kernel version, download the headers from Particle's APT repository:

```bash
# Add Particle repository (if not already configured)
# See Particle documentation for repository setup

# Download the kernel header packages
apt download linux-headers-6.8.0-1056-particle linux-particle-headers-6.8.0-1056

# Move to kernel-headers directory
mv linux-headers-*.deb linux-particle-headers-*.deb kernel-headers/
```

### Option 2: Use Included .deb Files

The repository includes the kernel header `.deb` packages for kernel `6.8.0-1056-particle`.

### Extract Headers

Extract the headers from the `.deb` packages:

```bash
cd kernel-headers

# Create extraction directory
mkdir -p extracted

# Extract both packages (order doesn't matter)
dpkg -x linux-particle-headers-6.8.0-1056_6.8.0-1056.57+particle4_all.deb extracted/
dpkg -x linux-headers-6.8.0-1056-particle_6.8.0-1056.57+particle4_arm64.deb extracted/

# Verify extraction
ls extracted/usr/src/linux-headers-6.8.0-1056-particle/
```

After extraction, you should have headers in `kernel-headers/extracted/usr/src/linux-headers-6.8.0-1056-particle/`.

---

## Build Host Setup

This project was developed and tested on the following build host:

| Property | Value |
|----------|-------|
| OS | Ubuntu 22.04 LTS (x86_64) |
| Kernel | 5.15+ |
| GCC (host) | 11.4.0 |
| Cross-compiler | gcc-aarch64-linux-gnu 11.4.0 |

### Required Packages

Install all required packages on your Ubuntu build host:

```bash
# Enable ARM64 architecture for cross-compilation libraries
sudo dpkg --add-architecture arm64
sudo apt-get update

# Cross-compiler toolchain
sudo apt-get install -y \
    gcc-aarch64-linux-gnu \
    g++-aarch64-linux-gnu

# Kernel module build tools
sudo apt-get install -y \
    make \
    flex \
    bison \
    bc \
    libssl-dev

# ARM64 libraries for wpa_supplicant_s1g
sudo apt-get install -y \
    libnl-3-dev:arm64 \
    libnl-genl-3-dev:arm64 \
    libssl-dev:arm64

# Optional: for morse_cli USB support
sudo apt-get install -y libusb-1.0-0-dev:arm64

# Utility packages
sudo apt-get install -y pkg-config
```

### Verify Installation

```bash
# Check cross-compiler
aarch64-linux-gnu-gcc --version

# Check ARM64 libraries
ls /usr/lib/aarch64-linux-gnu/libnl-3.so
ls /usr/lib/aarch64-linux-gnu/libssl.so
```

---

## Building

The top-level `Makefile` coordinates building all components:

```bash
# Build everything (driver + tools)
make

# Build only the kernel driver
make driver

# Build only tools (morse_cli + wpa_supplicant_s1g)
make tools

# Assemble deployment overlay
make overlay

# Clean all build artifacts
make clean

# Show all available targets
make help
```

### Manual Build (Individual Components)

If you prefer to build components individually:

#### Build Driver

```bash
cd driver
make -f Makefile.ubuntu \
    KERNEL_SRC=../kernel-headers/extracted/usr/src/linux-headers-6.8.0-1056-particle \
    ARCH=arm64 \
    CROSS_COMPILE=aarch64-linux-gnu-
```

#### Build wpa_supplicant_s1g

```bash
cd tools/wpa_supplicant_s1g/wpa_supplicant
CC=aarch64-linux-gnu-gcc \
PKG_CONFIG_PATH=/usr/lib/aarch64-linux-gnu/pkgconfig \
EXTRA_CFLAGS="-Wno-deprecated-declarations" \
make -j$(nproc) wpa_supplicant wpa_cli
```

#### Build morse_cli

```bash
cd tools/morsecli
make CC=aarch64-linux-gnu-gcc CONFIG_MORSE_TRANS_NL80211=1 morse_cli
```

---

## Deployment

### Manual Installation

```bash
# Copy modules to target
scp driver/morse_driver-1.16.4/morse.ko root@device:/lib/modules/
scp driver/morse_driver-1.16.4/dot11ah/dot11ah.ko root@device:/lib/modules/

# Copy firmware
scp -r firmware/* root@device:/lib/firmware/morse/

# Copy tools
scp tools/morsecli/morse_cli root@device:/usr/sbin/
scp tools/wpa_supplicant_s1g/wpa_supplicant/wpa_supplicant root@device:/usr/sbin/wpa_supplicant_s1g
scp tools/wpa_supplicant_s1g/wpa_supplicant/wpa_cli root@device:/usr/sbin/wpa_cli_s1g

# On target: run depmod
ssh root@device 'depmod -a'
```

### Tachyon Overlay

A ready-to-use Tachyon overlay is provided in `overlay/add-morse-halow/`. Copy to your tachyon-overlays directory and include in your build.

---

## Usage

### Load Driver

```bash
# Load modules (order matters)
insmod /lib/modules/dot11ah.ko
insmod /lib/modules/morse.ko

# Verify
lsmod | grep morse
dmesg | grep morse
```

### Connect to HaLow Network (WPA3-SAE)

```bash
# Create configuration
cat > /etc/wpa_supplicant/wpa_supplicant_s1g.conf << 'EOF'
ctrl_interface=/var/run/wpa_supplicant
ctrl_interface_group=netdev
update_config=1
country=US
sae_pwe=1

network={
    ssid="your_halow_network"
    sae_password="your_password"
    key_mgmt=SAE
    ieee80211w=2
}
EOF

# Start wpa_supplicant (interface name varies, e.g., wlx...)
wpa_supplicant_s1g -i wlx... -c /etc/wpa_supplicant/wpa_supplicant_s1g.conf -B -D nl80211

# Check status
wpa_cli_s1g -i wlx... status

# Get IP address
dhcpcd wlx...
```

### WPA3-SAE Configuration Notes

| Setting | Value | Description |
|---------|-------|-------------|
| `sae_pwe` | `1` | H2E mode (required for most HaLow APs) |
| `key_mgmt` | `SAE` | WPA3 authentication |
| `ieee80211w` | `2` | Protected Management Frames required |
| `sae_password` | (passphrase) | Use instead of `psk` for SAE |

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        User Space                               │
│  ┌──────────┐  ┌─────────────────┐  ┌──────────────────────┐   │
│  │morse_cli │  │ wpa_supplicant  │  │     hostapd_s1g      │   │
│  │          │  │     _s1g        │  │   (AP mode only)     │   │
│  └────┬─────┘  └───────┬─────────┘  └──────────┬───────────┘   │
│       │                │                       │                │
│       └────────────────┼───────────────────────┘                │
│                        │ nl80211                                │
├────────────────────────┼────────────────────────────────────────┤
│                   Kernel Space                                  │
│                   ┌────┴────┐                                   │
│                   │ cfg80211│                                   │
│                   └────┬────┘                                   │
│                   ┌────┴────┐                                   │
│                   │ mac80211│                                   │
│                   └────┬────┘                                   │
│              ┌─────────┴─────────┐                              │
│         ┌────┴────┐        ┌─────┴─────┐                        │
│         │morse.ko │◄───────│dot11ah.ko │                        │
│         └────┬────┘        └───────────┘                        │
│              │                                                  │
│         ┌────┴────┐                                             │
│         │USB Core │                                             │
│         └─────────┘                                             │
├─────────────────────────────────────────────────────────────────┤
│  /lib/firmware/morse/                                           │
│  ├── mm6108.bin, mm8108b2-rl.bin (chip firmware)               │
│  └── bcf_*.bin (board configurations)                          │
└─────────────────────────────────────────────────────────────────┘
```

---

## Tested Configuration

| Item | Value |
|------|-------|
| Platform | Tachyon (Particle) |
| Kernel | 6.8.0-1056-particle |
| Security | WPA3-SAE with H2E |
| Status | Fully operational |

---

## Modifications from Upstream

This repository contains the full source code from Morse Micro's upstream repositories with the following modifications applied. All original patches are preserved in the `patches/` directory for reference.

### OpenWrt Patches Applied

These patches are from the [morse-feed](https://github.com/MorseMicro/morse-feed) OpenWrt package and have been applied to the driver source:

| Patch | Description |
|-------|-------------|
| 0001 | Use 5-argument `cfg80211_port_authorized()` API (mac80211 v6.2+) |
| 003 | EKH01 SPI interface fixes (disable >50MHz clock check) |
| 004 | Fix kernel version check to use `MAC80211_VERSION_CODE` |
| 007 | Export board type via sysfs device attribute |
| 008 | Disable dynamic regulatory domain changes |
| 010 | Fix WDS 4-address mode probe request handling (use skb signature) |
| 013 | Remove x86_64-specific channel ignore workaround |
| 014 | Export available countries list via sysfs |
| 015 | Add 4.3V FEM GPIO support via module parameter |
| 990 | Capture TSF timestamp from RX frames for time synchronization |
| 991 | Add TSF debugfs interface (`/sys/kernel/debug/ieee80211/phy*/morse/tsf_rx`, `tsf_current`) |

### Ubuntu/GCC 13+ Compatibility Fixes

Additional modifications for building on Ubuntu 24.04 with GCC 13 and kernel 6.8:

| File | Modification |
|------|--------------|
| `backport/backport.h` | Created stub to map `IEEE80211_CHAN_IGNORE` → `IEEE80211_CHAN_DISABLED` (OpenWrt-specific flag not in mainline kernel) |
| `debug.h` | Fixed `morse_log_is_enabled()` return type (enum vs int mismatch) |
| `firmware.h` | Fixed `morse_firmware_init()` return type and added forward declaration |
| `mac.c` | Added `morse_get_tsf_snapshot()` forward declaration |

### Build System

| File | Description |
|------|-------------|
| `driver/Makefile.ubuntu` | Standalone cross-compilation makefile (no OpenWrt build system required) |
| `tools/wpa_supplicant_s1g/wpa_supplicant/.config` | Build configuration for ARM64 cross-compilation |

### Unmodified Components

The following components are included unmodified from upstream:

- **morse_cli** (`tools/morsecli/`) - v1.16.4 from [morse_cli](https://github.com/MorseMicro/morse_cli)
- **wpa_supplicant_s1g** (`tools/wpa_supplicant_s1g/`) - v1.16.4 from [hostap](https://github.com/MorseMicro/hostap)
- **Firmware** (`firmware/`) - v1.16.4 binaries from [morse-firmware](https://github.com/MorseMicro/morse-firmware)

---

## License

This repository contains components with different licenses:

| Component | License | Notes |
|-----------|---------|-------|
| morse_driver | GPLv2 | Full source included |
| morse_cli | GPLv2 | Full source included |
| hostap (wpa_supplicant_s1g) | BSD-3-Clause | Full source included |
| morse-firmware | Morse Micro Binary Distribution License | Use with Morse Micro hardware only |
| Build system & docs | MIT | Dusty Robotics additions |

See [LICENSE](LICENSE) for complete licensing details and [firmware/LICENSE](firmware/LICENSE) for firmware terms.
