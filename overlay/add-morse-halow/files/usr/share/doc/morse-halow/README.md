# Morse Micro HaLow (802.11ah) Driver for Ubuntu/Tachyon

This package provides the Morse Micro HaLow USB WiFi driver and tools for Ubuntu 24.04.

## Quick Start - Station Mode (Client)

### 1. Load the driver
```bash
modprobe morse country=US
```

### 2. Configure WPA supplicant
Edit `/etc/wpa_supplicant/wpa_supplicant_s1g.conf`:
```
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
```

### 3. Connect
```bash
# Find interface name (usually wlxXXXXXXXXXXXX)
IFACE=$(ip link show | grep -oE 'wlx[0-9a-f]+' | head -1)

# Start wpa_supplicant
wpa_supplicant_s1g -i $IFACE -c /etc/wpa_supplicant/wpa_supplicant_s1g.conf -B

# Get IP
dhclient $IFACE
```

### 4. Apply latency optimizations (optional)
```bash
halow-optimize $IFACE optimize   # Reduces latency from ~66ms to ~6ms
halow-optimize $IFACE status     # Check current settings
halow-optimize $IFACE reset      # Restore defaults
```

---

## Access Point (AP) Mode Setup

### Prerequisites
- hostapd with 802.11ah/S1G support (hostapd_s1g)
- Morse firmware files in /lib/firmware/morse/

### 1. Create hostapd configuration
Create `/etc/hostapd/hostapd_s1g.conf`:
```
# Interface and driver
interface=wlan0
driver=nl80211
hw_mode=s1g

# Network settings
ssid=my_halow_ap
country_code=US

# Channel configuration (US S1G band)
# Channel 28 = 5560 MHz representation, maps to ~915 MHz actual
channel=28
op_class=71

# S1G specific settings
s1g_oper_chwidth=4
s1g_prim_chwidth=1
s1g_prim_chwidth_loc=3

# Security - WPA3-SAE (recommended)
wpa=2
wpa_key_mgmt=SAE
wpa_passphrase=your_password
ieee80211w=2
sae_require_mfp=1
sae_pwe=1
group_mgmt_cipher=AES-128-CMAC

# Optional: Enable WDS (4-address mode)
wds_sta=1

# Performance tuning
wmm_enabled=1
```

### 2. Load driver in AP mode
```bash
modprobe morse country=US

# Create AP interface
iw phy phy0 interface add wlan0 type __ap
```

### 3. Start hostapd
```bash
hostapd_s1g /etc/hostapd/hostapd_s1g.conf
```

### 4. Configure DHCP server
Install and configure dnsmasq:
```bash
apt install dnsmasq

cat > /etc/dnsmasq.d/halow-ap.conf << EOF
interface=wlan0
dhcp-range=192.168.100.10,192.168.100.100,12h
dhcp-option=3,192.168.100.1
dhcp-option=6,8.8.8.8,8.8.4.4
EOF

# Set AP IP address
ip addr add 192.168.100.1/24 dev wlan0
ip link set wlan0 up

systemctl restart dnsmasq
```

---

## US S1G Channel Reference

| S1G Channel | Frequency (MHz) | 5GHz Equiv | Bandwidth |
|-------------|-----------------|------------|-----------|
| 1           | 902.5           | 5010       | 1 MHz     |
| 3           | 903.5           | 5030       | 1 MHz     |
| 5           | 906.5           | 5050       | 2 MHz     |
| 9           | 908.5           | 5090       | 2 MHz     |
| 13          | 910.5           | 5130       | 4 MHz     |
| 21          | 914.5           | 5210       | 4 MHz     |
| 28          | 915.0           | 5560       | 4 MHz     |
| 37          | 920.5           | 5370       | 8 MHz     |

Operating Classes:
- 68: 1 MHz channels
- 69: 2 MHz channels
- 71: 4 MHz channels
- 72: 8 MHz channels

---

## Security Options

### WPA3-SAE (Recommended)
```
wpa=2
wpa_key_mgmt=SAE
wpa_passphrase=your_password
ieee80211w=2
sae_require_mfp=1
sae_pwe=1
```

### WPA2-PSK (Legacy)
```
wpa=2
wpa_key_mgmt=WPA-PSK
wpa_passphrase=your_password
rsn_pairwise=CCMP
```

### Open (No Security)
```
# Not recommended for production
auth_algs=1
wpa=0
```

---

## Troubleshooting

### Check driver is loaded
```bash
lsmod | grep morse
dmesg | grep -i morse
```

### Check interface exists
```bash
ip link show | grep wlx
iw dev
```

### Check connection status
```bash
wpa_cli_s1g -p /var/run/wpa_supplicant -i $IFACE status
```

### View driver statistics
```bash
morse_cli -i $IFACE stats
morse_cli -i $IFACE channel
```

### Debug wpa_supplicant
```bash
# Run in foreground with debug output
wpa_supplicant_s1g -i $IFACE -c /etc/wpa_supplicant/wpa_supplicant_s1g.conf -d
```

### Common issues

1. **"TEMP-DISABLED" in wpa_cli status**
   - Wrong security settings. For WPA3-SAE, ensure `sae_pwe=1` and `key_mgmt=SAE`

2. **No interface created after modprobe**
   - Check USB device: `lsusb | grep -i morse`
   - Check dmesg for errors: `dmesg | tail -20`

3. **High latency (>50ms)**
   - Run `halow-optimize` to apply latency optimizations

4. **Association timeout**
   - Verify country code matches AP
   - Check channel/operating class compatibility

---

## Installed Files

| Path | Description |
|------|-------------|
| /lib/modules/.../morse.ko | Main driver module |
| /lib/modules/.../dot11ah.ko | 802.11ah MAC layer |
| /lib/firmware/morse/ | Firmware files |
| /usr/sbin/morse_cli | CLI management tool |
| /usr/sbin/morsectrl | Symlink to morse_cli |
| /usr/sbin/wpa_supplicant_s1g | WPA supplicant with S1G support |
| /usr/sbin/wpa_cli_s1g | WPA CLI with S1G support |
| /usr/sbin/halow-optimize | Latency optimization script |
| /etc/wpa_supplicant/wpa_supplicant_s1g.conf | WPA config template |
| /etc/modprobe.d/morse.conf | Module options |

---

## References

- Morse Micro: https://www.morsemicro.com/
- 802.11ah (HaLow) specification: IEEE 802.11ah-2016
- US S1G band: 902-928 MHz (ISM band)
