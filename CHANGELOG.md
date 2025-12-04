# Changelog

## 2024-12-04 - Documentation Update

- Created partner-ready README.md with comprehensive overview
- Added TECHNICAL.md with detailed technical reference
- Simplified CLAUDE.md to internal working notes
- Removed tachyon.md (content merged into README.md and TECHNICAL.md)

## 2024-12-03 - Hardware Verified

- Successfully connected to HaLow AP with WPA3-SAE
- Confirmed wpa_supplicant_s1g and wpa_cli_s1g functionality
- Verified H2E mode (sae_pwe=1) required for most HaLow APs

## 2024-12-02 - Project Complete

### Driver
- Built morse.ko and dot11ah.ko for kernel 6.8.0-1056-particle
- Applied all 12 OpenWrt patches
- Fixed GCC 13+ enum/integer type mismatches
- Created Makefile.ubuntu for standalone cross-compilation

### Tools
- Built morse_cli v1.16.4 for ARM64
- Built wpa_supplicant_s1g and wpa_cli_s1g for ARM64

### Firmware
- Collected 27 firmware files (5 chip firmware, 22 board configs)

### Tachyon Overlay
- Created complete overlay in overlay/add-morse-halow/
- Includes modules, firmware, tools, udev rules, and install script

## Initial Setup

### Patches Applied
| # | Description |
|---|-------------|
| 0001 | cfg80211_port_authorized 5-arg API |
| 003 | EKH01 SPI fixes |
| 004 | Kernel version check fix |
| 007 | Sysfs board type export |
| 008 | Disable dynamic regulatory changes |
| 010 | WDS 4-addr mode fix |
| 013 | Remove x86_64 chan ignore workaround |
| 014 | Sysfs countries list |
| 015 | 4.3V FEM GPIO support |
| 990-991 | TSF capture and debugfs interfaces |

### Ubuntu Fixes
- backport/backport.h: Map IEEE80211_CHAN_IGNORE
- debug.h: morse_log_is_enabled() enum type
- firmware.h: morse_firmware_init() enum type
- mac.c: morse_get_tsf_snapshot() forward declaration
