#!/bin/bash
# Install Morse Micro HaLow driver modules

set -e

# In chroot, uname -r returns host kernel, so use the installed kernel
KERNEL_VERSION=$(ls /lib/modules | grep -E '^[0-9]+\.' | head -1)
MODULE_DIR="/lib/modules/${KERNEL_VERSION}/extra/morse"

echo "Installing Morse HaLow driver for kernel ${KERNEL_VERSION}..."

# Create module directory
mkdir -p "${MODULE_DIR}"

# Move modules to proper location
mv /lib/modules/dot11ah.ko "${MODULE_DIR}/"
mv /lib/modules/morse.ko "${MODULE_DIR}/"

# Update module dependencies
depmod -a "${KERNEL_VERSION}"

# Create modprobe config for module options
cat > /etc/modprobe.d/morse.conf << 'EOF'
# Morse Micro HaLow driver options
# Set default country code (US)
options morse country=US
EOF

# Create morsectrl symlink for compatibility (morse_cli is the new name)
ln -sf /usr/sbin/morse_cli /usr/sbin/morsectrl

echo "Morse HaLow driver installed successfully."
echo "Modules: ${MODULE_DIR}/morse.ko, ${MODULE_DIR}/dot11ah.ko"
echo "Firmware: /lib/firmware/morse/"
echo "CLI tools: /usr/sbin/morse_cli"
echo "WPA supplicant: /usr/sbin/wpa_supplicant_s1g"
echo "WPA CLI: /usr/sbin/wpa_cli_s1g"
echo "Config: /etc/wpa_supplicant/wpa_supplicant_s1g.conf"
