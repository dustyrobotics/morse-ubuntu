# Morse Micro HaLow Driver - Top-level Makefile
#
# Builds the driver, tools, and assembles the overlay for ARM64/Tachyon deployment.
#
# Usage:
#   make                    # Build everything
#   make driver             # Build kernel modules only
#   make tools              # Build morse_cli and wpa_supplicant_s1g
#   make overlay            # Assemble overlay from built artifacts
#   make clean              # Clean all build artifacts
#
# Requirements:
#   - Ubuntu 22.04+ (x86_64) build host
#   - ARM64 cross-compiler: gcc-aarch64-linux-gnu
#   - ARM64 libraries: libnl-3-dev:arm64, libnl-genl-3-dev:arm64, libssl-dev:arm64
#   - Build tools: make, flex, bison, pkg-config
#
# See README.md for full setup instructions.

# Configuration
ARCH := arm64
CROSS_COMPILE := aarch64-linux-gnu-
CC := $(CROSS_COMPILE)gcc
PKG_CONFIG := pkg-config

# Kernel headers (must be extracted first)
KERNEL_VERSION := 6.8.0-1056-particle
KERNEL_HEADERS := $(CURDIR)/kernel-headers/extracted/usr/src/linux-headers-$(KERNEL_VERSION)

# Directories
DRIVER_DIR := $(CURDIR)/driver
DRIVER_SRC := $(DRIVER_DIR)/morse_driver-1.16.4
MORSECLI_DIR := $(CURDIR)/tools/morsecli
WPA_DIR := $(CURDIR)/tools/wpa_supplicant_s1g/wpa_supplicant
HOSTAPD_DIR := $(CURDIR)/tools/wpa_supplicant_s1g/hostapd
FIRMWARE_DIR := $(CURDIR)/firmware
OVERLAY_DIR := $(CURDIR)/overlay/add-morse-halow/files

# Build outputs
MORSE_KO := $(DRIVER_SRC)/morse.ko
DOT11AH_KO := $(DRIVER_SRC)/dot11ah/dot11ah.ko
MORSE_CLI := $(MORSECLI_DIR)/morse_cli
WPA_SUPPLICANT := $(WPA_DIR)/wpa_supplicant
WPA_CLI := $(WPA_DIR)/wpa_cli
HOSTAPD := $(HOSTAPD_DIR)/hostapd_s1g
HOSTAPD_CLI := $(HOSTAPD_DIR)/hostapd_cli_s1g

# Parallel jobs (override with make -jN or JOBS=N)
JOBS ?= $(shell nproc)

.PHONY: all driver tools morsecli wpa_supplicant hostapd overlay clean clean-driver clean-tools help check-deps check-headers

# Default target
all: check-headers driver tools
	@echo ""
	@echo "Build complete!"
	@echo "  Driver modules: $(MORSE_KO)"
	@echo "                  $(DOT11AH_KO)"
	@echo "  morse_cli:      $(MORSE_CLI)"
	@echo "  wpa_supplicant: $(WPA_SUPPLICANT)"
	@echo "  hostapd:        $(HOSTAPD)"
	@echo ""
	@echo "Run 'make overlay' to assemble the deployment overlay."

# Check that kernel headers are extracted
check-headers:
	@if [ ! -d "$(KERNEL_HEADERS)" ]; then \
		echo "Error: Kernel headers not found at $(KERNEL_HEADERS)"; \
		echo ""; \
		echo "Please extract the kernel headers first:"; \
		echo "  cd kernel-headers"; \
		echo "  mkdir -p extracted"; \
		echo "  dpkg -x linux-particle-headers-*.deb extracted/"; \
		echo "  dpkg -x linux-headers-*-particle_*.deb extracted/"; \
		echo ""; \
		exit 1; \
	fi

# Check build dependencies
check-deps:
	@echo "Checking build dependencies..."
	@which $(CC) > /dev/null || (echo "Error: $(CC) not found. Install gcc-aarch64-linux-gnu" && exit 1)
	@which flex > /dev/null || (echo "Error: flex not found. Install flex" && exit 1)
	@which bison > /dev/null || (echo "Error: bison not found. Install bison" && exit 1)
	@echo "All dependencies found."

#
# Driver build
#
driver: check-headers $(MORSE_KO)

$(MORSE_KO): FORCE
	@echo "Building kernel driver modules..."
	$(MAKE) -C $(DRIVER_DIR) -f Makefile.ubuntu \
		KERNEL_SRC=$(KERNEL_HEADERS) \
		ARCH=$(ARCH) \
		CROSS_COMPILE=$(CROSS_COMPILE)
	@echo "Driver modules built:"
	@ls -lh $(MORSE_KO) $(DOT11AH_KO)

#
# Tools build
#
tools: morsecli wpa_supplicant hostapd

morsecli: $(MORSE_CLI)

$(MORSE_CLI): FORCE
	@echo "Building morse_cli..."
	$(MAKE) -C $(MORSECLI_DIR) \
		CC=$(CC) \
		PKG_CONFIG=$(PKG_CONFIG) \
		CONFIG_MORSE_TRANS_NL80211=1 \
		SYSROOT=/usr/aarch64-linux-gnu \
		morse_cli
	@echo "morse_cli built:"
	@ls -lh $(MORSE_CLI)
	@file $(MORSE_CLI)

wpa_supplicant: $(WPA_SUPPLICANT)

$(WPA_SUPPLICANT): FORCE
	@echo "Building wpa_supplicant_s1g..."
	$(MAKE) -C $(WPA_DIR) \
		CC=$(CC) \
		PKG_CONFIG_PATH=/usr/lib/aarch64-linux-gnu/pkgconfig \
		EXTRA_CFLAGS="-Wno-deprecated-declarations" \
		-j$(JOBS) \
		wpa_supplicant wpa_cli
	@echo "wpa_supplicant_s1g built:"
	@ls -lh $(WPA_SUPPLICANT) $(WPA_CLI)
	@file $(WPA_SUPPLICANT)

hostapd: $(HOSTAPD)

$(HOSTAPD): FORCE
	@echo "Building hostapd_s1g..."
	PKG_CONFIG_PATH=/usr/lib/aarch64-linux-gnu/pkgconfig \
	$(MAKE) -C $(HOSTAPD_DIR) \
		CC=$(CC) \
		EXTRA_CFLAGS="-Wno-deprecated-declarations" \
		-j$(JOBS)
	@echo "hostapd_s1g built:"
	@ls -lh $(HOSTAPD) $(HOSTAPD_CLI)
	@file $(HOSTAPD)

#
# Overlay assembly
#
overlay: all
	@echo "Assembling deployment overlay..."
	@mkdir -p $(OVERLAY_DIR)/lib/modules
	@mkdir -p $(OVERLAY_DIR)/lib/firmware/morse
	@mkdir -p $(OVERLAY_DIR)/usr/sbin
	@# Copy kernel modules
	cp $(MORSE_KO) $(OVERLAY_DIR)/lib/modules/
	cp $(DOT11AH_KO) $(OVERLAY_DIR)/lib/modules/
	@# Copy firmware
	cp -a $(FIRMWARE_DIR)/* $(OVERLAY_DIR)/lib/firmware/morse/
	@# Copy tools
	cp $(MORSE_CLI) $(OVERLAY_DIR)/usr/sbin/
	cp $(WPA_SUPPLICANT) $(OVERLAY_DIR)/usr/sbin/wpa_supplicant_s1g
	cp $(WPA_CLI) $(OVERLAY_DIR)/usr/sbin/wpa_cli_s1g
	cp $(HOSTAPD) $(OVERLAY_DIR)/usr/sbin/hostapd_s1g
	cp $(HOSTAPD_CLI) $(OVERLAY_DIR)/usr/sbin/hostapd_cli_s1g
	@echo ""
	@echo "Overlay assembled in $(OVERLAY_DIR)"
	@echo "Contents:"
	@find $(OVERLAY_DIR) -type f | head -20

#
# Clean targets
#
clean: clean-driver clean-tools
	@echo "Clean complete."

clean-driver:
	@echo "Cleaning driver build artifacts..."
	-$(MAKE) -C $(DRIVER_DIR) -f Makefile.ubuntu \
		KERNEL_SRC=$(KERNEL_HEADERS) \
		clean 2>/dev/null || true
	find $(DRIVER_SRC) -name "*.o" -delete 2>/dev/null || true
	find $(DRIVER_SRC) -name "*.ko" -delete 2>/dev/null || true
	find $(DRIVER_SRC) -name "*.mod" -delete 2>/dev/null || true
	find $(DRIVER_SRC) -name "*.mod.c" -delete 2>/dev/null || true
	find $(DRIVER_SRC) -name ".*.cmd" -delete 2>/dev/null || true
	find $(DRIVER_SRC) -name "modules.order" -delete 2>/dev/null || true
	find $(DRIVER_SRC) -name "Module.symvers" -delete 2>/dev/null || true
	rm -rf $(DRIVER_SRC)/.tmp_versions 2>/dev/null || true

clean-tools:
	@echo "Cleaning tools build artifacts..."
	-$(MAKE) -C $(MORSECLI_DIR) clean 2>/dev/null || true
	-$(MAKE) -C $(WPA_DIR) clean 2>/dev/null || true
	-$(MAKE) -C $(HOSTAPD_DIR) clean 2>/dev/null || true

#
# Help
#
help:
	@echo "Morse Micro HaLow Driver Build System"
	@echo ""
	@echo "Targets:"
	@echo "  all            Build driver and tools (default)"
	@echo "  driver         Build kernel modules (morse.ko, dot11ah.ko)"
	@echo "  tools          Build morse_cli, wpa_supplicant_s1g, and hostapd_s1g"
	@echo "  morsecli       Build morse_cli only"
	@echo "  wpa_supplicant Build wpa_supplicant_s1g only"
	@echo "  hostapd        Build hostapd_s1g only"
	@echo "  overlay        Assemble deployment overlay from built artifacts"
	@echo "  clean          Clean all build artifacts"
	@echo "  check-deps     Verify build dependencies are installed"
	@echo "  help           Show this help"
	@echo ""
	@echo "Variables:"
	@echo "  JOBS=N         Parallel build jobs (default: $(JOBS))"
	@echo "  V=1            Verbose build output"
	@echo ""
	@echo "Prerequisites:"
	@echo "  1. Extract kernel headers: see 'Kernel Header Setup' in README.md"
	@echo "  2. Install dependencies:   see 'Build Host Setup' in README.md"
	@echo ""

# Force rebuild
FORCE:
