# Public IP Rotator (`ksu_ip_rotator`)

A **KernelSU-Next / KernelSU / APatch / Magisk** module that randomly rotates your device's **Public IP address on Wi-Fi** whenever you tap the **Action** button in your root manager.

**Author:** `hiruko-puppetmaster`

---

## Features
- **Interactive Volume-Key Installer:** Choose between **WireGuard Mode** (`Vol+`) or **Tor / Orbot Mode** (`Vol-`) during flashing.
- **WireGuard Config Rotator (`MODE="WIREGUARD"`):** Picks a random `.conf` tunnel from `/data/adb/ip_rotator/wg_configs/`, avoids repeating the previously used server, sanitizes interface names (`wg0.conf`), and switches tunnels on the fly.
- **Tor Circuit Reset (`MODE="TOR"`):** Sends `SIGNAL NEWNYM` to Tor's ControlPort (`127.0.0.1:9051`) to rotate exit nodes in under a second without dropping connectivity.
- **Live Action Console + Toast Notification:** Prints your old and new Public IP, city, country, and ISP directly in the KernelSU-Next console and posts an Android system notification.

---

## Quick Setup Guide

### 1. WireGuard Mode (Fastest Speeds)
1. Download 5 to 10 free WireGuard (`.conf`) files from **ProtonVPN** (Free tier) or **Cloudflare WARP** (`wgcf`).
2. Place your `.conf` files into:
   ```text
   /data/adb/ip_rotator/wg_configs/
   ```
3. Ensure the **WireGuard** app (with command-line tools enabled in settings) or a `wg-quick` CLI binary is installed.
4. Tap **Action** in KernelSU-Next Manager to jump to a random server.

### 2. Tor / Orbot Mode (Infinite IPs)
1. Install **Orbot** (enable VPN/Root mode) and enable **Control Port `9051`** in Orbot settings.
2. Set `TOR` inside `/data/adb/ip_rotator/mode.conf` (or select `[Vol-]` during installation).
3. Tap **Action** in KernelSU-Next Manager to force a new Tor exit node (`NEWNYM`).
