# TorBox TOGGLE Variables (01-25)

This document lists all TOGGLE variables used in the TorBox project with their functions.

## Variable List

| Variable | Function | Status |
|----------|----------|--------|
| TOGGLE01 | OpenVPN server enable/disable status | Used |
| TOGGLE02 | OpenVPN server configuration message | Used |
| TOGGLE03 | Logging extent indicator (LOW/HIGH) | Used |
| TOGGLE04 | Logging extent toggle target (HIGH/LOW) | Used |
| TOGGLE05 | Current WLAN frequency band (2.5 GHz/5 GHz) | Used |
| TOGGLE06 | Target WLAN frequency band for switching | Used |
| TOGGLE07 | Bridge Relay mode status / WLAN channel number | Used |
| TOGGLE08 | Bridge Relay mode toggle target / SSID visibility | Used |
| TOGGLE09 | TorBox WLAN enable/disable status | Used |
| TOGGLE10 | Tor Bandwidth Limit started/stopped status | Used |
| TOGGLE11 | Root access enable/disable status | Used |
| TOGGLE12 | HTTP plain text traffic block enable/disable status | Used |
| TOGGLE13 | HTTP block additional info message (SOCKS 5 note) | Used |
| TOGGLE14 | Tor control port access for clients enable/disable | Used |
| TOGGLE15 | Tor control port access recommendation message | Used |
| TOGGLE16 | Onion Service mode status | Used |
| TOGGLE17 | WebSSH access enable/disable status | Used |
| TOGGLE18 | Slow tor relays exclusion start/stop status | Used |
| TOGGLE19 | Domain exclusion from tor protection start/stop status | Used |
| TOGGLE20 | WLAN1 failsafe enable/disable status | Used |
| TOGGLE21 | SSH password login enable/disable status | Used |
| TOGGLE22 | OpenVPN server management/installation status | Used |
| TOGGLE23 | TorBox mini default configuration activate/deactivate | Used |
| TOGGLE24 | NOT USED | Not Used |
| TOGGLE25 | NOT USED | Not Used |

## Detailed Descriptions

### TOGGLE01 & TOGGLE02
- **Location**: `install/openvpn-install.sh`
- **Function**: TOGGLE01 shows if the OpenVPN server is enabled or disabled. TOGGLE02 provides additional context message.

### TOGGLE03 & TOGGLE04
- **Location**: `menu-config`
- **Function**: Control logging extent. TOGGLE03 shows current setting (LOW/HIGH), TOGGLE04 shows target setting for switching.

### TOGGLE05 & TOGGLE06
- **Location**: `menu-config`
- **Function**: Manage WLAN frequency bands. TOGGLE05 shows current band (2.5 GHz or 5 GHz), TOGGLE06 shows target band for switching.

### TOGGLE07 & TOGGLE08
- **Location**: `menu-server`, `menu-config`
- **Function**: In menu-server: Bridge Relay mode status. In menu-config: WLAN channel number and SSID visibility.

### TOGGLE09
- **Location**: `menu-config`
- **Function**: Shows if TorBox's WLAN is enabled or disabled.

### TOGGLE10
- **Status**: `menu-config`
- **Function**: Shows if tor bandwidth limit is started or not

### TOGGLE11
- **Location**: `menu-config`
- **Function**: Shows if root access is enabled or disabled.

### TOGGLE12 & TOGGLE13
- **Location**: `menu-config`
- **Function**: TOGGLE12 controls HTTP plain text traffic blocking. TOGGLE13 provides additional info about SOCKS 5.

### TOGGLE14 & TOGGLE15
- **Location**: `menu-config`
- **Function**: TOGGLE14 controls Tor control port access for clients. TOGGLE15 shows recommendation message.

### TOGGLE16
- **Location**: `menu-onion`, `menu`
- **Function**: Shows Onion Service mode status (running/not running).

### TOGGLE17
- **Location**: `menu-config`
- **Function**: Shows if WebSSH access is enabled or disabled.

### TOGGLE18
- **Location**: `menu-config`
- **Function**: Shows if slow tor relays exclusion is active.

### TOGGLE19
- **Location**: `menu-danger`
- **Function**: Shows if domain exclusion from tor protection is active.

### TOGGLE20
- **Location**: `menu-danger`
- **Function**: Shows if the AP on wlan1 failsafe is enabled or disabled.

### TOGGLE21
- **Location**: `menu-danger`
- **Function**: Shows if SSH password login is enabled or disabled.

### TOGGLE22
- **Location**: `menu-config`
- **Function**: Shows OpenVPN server management/installation status.

### TOGGLE23
- **Location**: `menu-danger`
- **Function**: Shows if TorBox mini default configuration is activated or deactivated.

### TOGGLE24 & TOGGLE25
- **Status**: NOT USED
- **Function**: Reserved for future use.
