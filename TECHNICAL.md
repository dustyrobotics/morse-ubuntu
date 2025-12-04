# Technical Reference

Detailed technical information for the Morse Micro HaLow driver port.

## Kernel Compatibility

### Target Kernel
| Property | Value |
|----------|-------|
| Version | 6.8.0-1056-particle |
| Flavor | arm64-qcom (Qualcomm/Particle) |
| Source tag | stable-6.8.0-1056.57particle4 |

### Required Kernel Config
```
CONFIG_WIRELESS=y
CONFIG_CFG80211=m
CONFIG_MAC80211=m
CONFIG_USB_EHCI_HCD=y
CONFIG_USB_XHCI_HCD=y
CONFIG_CRYPTO_AES=y
```

### API Compatibility
All driver APIs are compatible with kernel 6.8:
- `cfg80211_port_authorized()` - 5 arguments
- `ieee80211_is_bufferable_mmpdu()` - skb signature
- mac80211 version macros via `LINUX_VERSION_CODE`

### Dependencies
| Dependency | Required | Notes |
|------------|----------|-------|
| trelay | No | OpenWrt package dependency only |
| ubus | No | Optional, socket interface works |
| morse-regdb | No | Built into driver |
| mac80211 backport | No | Native kernel 6.8 APIs work |

---

## Patches Applied

### OpenWrt Patches
All 12 patches from OpenWrt feeds/morse applied:

| # | Description |
|---|-------------|
| 0001 | `cfg80211_port_authorized()` 5-argument API adaptation |
| 003 | EKH01 SPI interface fixes |
| 004 | Kernel version check fix |
| 007 | Sysfs board type export |
| 008 | Disable dynamic regulatory changes |
| 010 | WDS 4-address mode fix (skb signature) |
| 013 | Remove x86_64 channel ignore workaround |
| 014 | Sysfs countries list export |
| 015 | 4.3V FEM GPIO support |
| 990 | TSF capture from RX frames |
| 991 | TSF debugfs interface |

### Ubuntu/GCC 13+ Fixes
Additional fixes applied for Ubuntu 24.04 and GCC 13:

| File | Fix |
|------|-----|
| `backport/backport.h` | Map `IEEE80211_CHAN_IGNORE` to `IEEE80211_CHAN_DISABLED` |
| `debug.h:159` | `morse_log_is_enabled()` enum type |
| `firmware.h:149` | `morse_firmware_init()` enum type + forward declaration |
| `mac.c:87` | `morse_get_tsf_snapshot()` forward declaration |

---

## Firmware Files

### Chip Firmware
| File | Chipset | Description |
|------|---------|-------------|
| mm6108.bin | MM6108 | Standard firmware |
| mm6108-tlm.bin | MM6108 | Thin LMAC firmware |
| mm8108b2-rl.bin | MM8108B2 | Standard firmware |
| mm8108b2-tlm-rl.bin | MM8108B2 | Thin LMAC firmware |
| mm8108b2-flm-rl.bin | MM8108B2 | Full LMAC firmware |

### Board Configuration Files (bcf_*.bin)
22 board configuration files for various hardware modules:
- HM593, HM677 (AW modules)
- MF08651, MF15457, MF28551 (various boards)
- MM-HL1 (reference design)
- Board type configurations (0801, 0802, 0804, 0807, 0a01, 0a02)
- FGH100M series

`bcf_default.bin` is a symlink to `bcf_failsafe.bin` for generic operation.

---

## Build System

### Makefile.ubuntu
The `driver/Makefile.ubuntu` provides standalone cross-compilation without requiring the full OpenWrt build system.

Key variables:
- `KERNEL_SRC` - Path to kernel headers
- `ARCH` - Target architecture (arm64)
- `CROSS_COMPILE` - Cross-compiler prefix

### Module Output
| Module | Purpose | Size |
|--------|---------|------|
| morse.ko | Main driver, USB interface | ~24MB (debug) |
| dot11ah.ko | 802.11ah MAC layer | ~2.5MB (debug) |

Debug symbols can be stripped for production deployment.

---

## Tachyon Overlay Structure

```
overlay/add-morse-halow/
├── overlay.json                         # Tachyon install config
└── files/
    ├── lib/
    │   ├── firmware/morse/              # All 27 firmware files
    │   └── modules/
    │       ├── morse.ko
    │       └── dot11ah.ko
    ├── usr/sbin/
    │   ├── morse_cli
    │   ├── wpa_supplicant_s1g
    │   └── wpa_cli_s1g
    ├── etc/
    │   ├── udev/rules.d/
    │   │   └── 99-morse-halow.rules     # USB hotplug
    │   └── wpa_supplicant/
    │       └── wpa_supplicant_s1g.conf  # Sample config
    └── install-morse.sh                 # depmod setup
```

---

## Debugging

### Kernel Logs
```bash
dmesg | grep morse
dmesg | grep dot11ah
```

### Driver Info
```bash
morse_cli version
morse_cli stats
morse_cli channel
```

### WPA Supplicant Status
```bash
wpa_cli_s1g -i <interface> status
wpa_cli_s1g -i <interface> scan_results
```

### Debugfs (if enabled)
```bash
ls /sys/kernel/debug/ieee80211/phy*/morse/
```
