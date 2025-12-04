# Claude Code Notes

Internal reference for working with this codebase. For partner documentation, see [README.md](README.md).

## Quick Build

```bash
# Full build (after extracting kernel headers)
make

# Individual targets
make driver          # kernel modules only
make tools           # morse_cli + wpa_supplicant_s1g
make overlay         # assemble deployment package
make clean           # clean all artifacts
```

## Repository Layout

```
morse-ubuntu/
├── Makefile                    # Top-level build orchestration
├── driver/
│   ├── Makefile.ubuntu         # Driver build entry point
│   └── morse_driver-1.16.4/    # Driver source (patches applied)
│       ├── morse.ko            # Main driver (output)
│       ├── dot11ah/dot11ah.ko  # MAC layer (output)
│       ├── backport/backport.h # Ubuntu compatibility shim
│       ├── mac.c               # Core MAC handling, TSF capture
│       ├── debug.c             # Debugfs interfaces
│       └── skbq.c              # TX/RX queue management
├── tools/
│   ├── morsecli/               # CLI tool source
│   │   └── morse_cli           # Binary (output)
│   └── wpa_supplicant_s1g/     # WPA supplicant fork
│       └── wpa_supplicant/
│           ├── .config         # Build configuration
│           ├── wpa_supplicant  # Binary (output)
│           └── wpa_cli         # Binary (output)
├── firmware/                   # Binary firmware files (unmodified)
├── kernel-headers/
│   ├── *.deb                   # Particle kernel header packages
│   └── extracted/              # Extracted headers (gitignored)
├── patches/                    # Original patch files (reference)
└── overlay/add-morse-halow/    # Tachyon deployment overlay
```

## Key Source Files

### Driver Core
| File | Purpose |
|------|---------|
| `driver/morse_driver-1.16.4/mac.c` | Main MAC layer, RX/TX paths, TSF capture |
| `driver/morse_driver-1.16.4/wiphy.c` | cfg80211 interface, connection handling |
| `driver/morse_driver-1.16.4/usb.c` | USB transport layer |
| `driver/morse_driver-1.16.4/firmware.c` | Firmware loading, BCF parsing |
| `driver/morse_driver-1.16.4/debug.c` | Debugfs interfaces (tsf_rx, tsf_current) |
| `driver/morse_driver-1.16.4/skbq.c` | SKB queue management, TX status |
| `driver/morse_driver-1.16.4/dot11ah/` | 802.11ah MAC sublayer |

### Build Configuration
| File | Purpose |
|------|---------|
| `driver/Makefile.ubuntu` | Standalone driver build (no OpenWrt) |
| `driver/morse_driver-1.16.4/Makefile` | Kernel module kbuild |
| `driver/morse_driver-1.16.4/backport/backport.h` | Kernel API compatibility |
| `tools/wpa_supplicant_s1g/wpa_supplicant/.config` | wpa_supplicant features |

## Architecture

### Module Stack
```
┌─────────────────────────────────┐
│     wpa_supplicant_s1g          │  User space
│     morse_cli                   │
├─────────────────────────────────┤
│     nl80211 / cfg80211          │  Kernel
├─────────────────────────────────┤
│     mac80211                    │
├─────────────────────────────────┤
│     morse.ko ◄── dot11ah.ko     │  This driver
├─────────────────────────────────┤
│     USB core                    │
└─────────────────────────────────┘
```

### Data Flow (RX)
1. USB bulk transfer → `morse_usb_rx_complete()` in usb.c
2. SKB queued → `morse_skbq_rx()` in skbq.c
3. MAC processing → `morse_mac_skb_recv()` in mac.c
4. TSF captured from `morse_skb_rx_status.rx_timestamp_us`
5. Frame passed to mac80211 → `ieee80211_rx_napi()`

### TSF Synchronization (patches 990-991)
- RX data frames trigger `morse_capture_rx_tsf()` in mac.c
- Stores hardware TSF (us) + kernel time (ns) atomically
- Exposed via debugfs: `/sys/kernel/debug/ieee80211/phy*/morse/tsf_rx`
- `tsf_current` extrapolates current TSF from last capture

## Hardware

| Property | Value |
|----------|-------|
| USB Vendor ID | `0x325b` (Morse Micro) |
| USB Product ID | `0x8100` |
| Chipsets | MM6108, MM8108B2 |
| Interface | USB bulk transfers |
| Firmware path | `/lib/firmware/morse/` |

## WPA3-SAE Configuration

Required settings for HaLow AP connection:
```
sae_pwe=1           # H2E mode (Hash-to-Element)
key_mgmt=SAE        # WPA3 authentication
ieee80211w=2        # PMF required
```

## Debugging

### Kernel logs
```bash
dmesg | grep -E "(morse|dot11ah)"
```

### Driver debugfs
```bash
# TSF from last RX frame
cat /sys/kernel/debug/ieee80211/phy*/morse/tsf_rx

# Extrapolated current TSF
cat /sys/kernel/debug/ieee80211/phy*/morse/tsf_current
```

### WPA supplicant
```bash
wpa_cli_s1g -i <iface> status
wpa_cli_s1g -i <iface> scan_results
```

### morse_cli
```bash
morse_cli -i <iface> version
morse_cli -i <iface> stats
morse_cli -i <iface> channel
```

## Cross-Compilation Notes

### Kernel Module
- Must use exact kernel headers from target device
- `KERNEL_SRC` points to extracted headers, not full kernel source
- `MAC80211_VERSION_CODE` not defined; uses `LINUX_VERSION_CODE`

### ARM64 Libraries
Required for wpa_supplicant_s1g:
- `libnl-3-dev:arm64`
- `libnl-genl-3-dev:arm64`
- `libssl-dev:arm64`

PKG_CONFIG_PATH must point to ARM64 pkgconfig:
```bash
PKG_CONFIG_PATH=/usr/lib/aarch64-linux-gnu/pkgconfig
```

## Common Issues

### "IEEE80211_CHAN_IGNORE undeclared"
The `backport/backport.h` maps this OpenWrt-specific flag to `IEEE80211_CHAN_DISABLED`.

### GCC 13 enum/int warnings as errors
Fixed in `debug.h` and `firmware.h` - return types changed from `int` to proper enums.

### wpa_supplicant deprecated warnings
Build with `EXTRA_CFLAGS="-Wno-deprecated-declarations"`.
