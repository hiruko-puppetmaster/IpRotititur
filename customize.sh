#!/system/bin/sh
##########################################################################################
#
# Magisk / KernelSU / APatch / TWRP Module Installer (customize.sh)
# Console UI + Volume-Key Selector + Recovery Progress Support
#
##########################################################################################

SKIPMOUNT=false
PROPFILE=false
POSTFSDATA=false
LATESTARTSERVICE=false

CONFIG_DIR="/data/adb/ip_rotator"
WG_DIR="$CONFIG_DIR/wg_configs"

# Helper to update TWRP/OrangeFox native progress bar safely
twrp_progress() {
  if [ "$BOOTMODE" = "false" ] && [ -n "$OUTFD" ]; then
    echo "set_progress $1" >&$OUTFD
  fi
}

# Volume-Key Selector (Returns 0 for Vol+, 1 for Vol-)
chooseport() {
  local delay=${1:-10}
  while true; do
    local event=$(timeout $delay getevent -lc 1 2>&1 | tr -d '\r')
    case "$event" in
      *KEY_VOLUMEUP*DOWN*) return 0 ;;
      *KEY_VOLUMEDOWN*DOWN*) return 1 ;;
    esac
  done
}

# ASCII Banner (Sized under 60 chars to prevent portrait line-wrapping)
ui_banner() {
  ui_print " "
  ui_print " ██╗█████╗  █████╗  ████╗ ██████╗ ████╗ ██████╗ ████╗ █████╗"
  ui_print " ██║██╔═██╗ ██╔═██╗██╔═██╗╚═██╔═╝██╔═██╗╚═██╔═╝██╔═██╗██╔═██╗"
  ui_print " ██║█████╔╝ █████╔╝██║ ██║  ██║  ██████║  ██║  ██║ ██║█████╔╝"
  ui_print " ██║██╔══╝  ██╔═██╗██║ ██║  ██║  ██╔═██║  ██║  ██║ ██║██╔═██╗"
  ui_print " ██║██║     ██║ ██║╚████╔╝  ██║  ██║ ██║  ██║  ╚████╔╝██║ ██║"
  ui_print " ╚═╝╚═╝     ╚═╝ ╚═╝ ╚═══╝   ╚═╝  ╚═╝ ╚═╝  ╚═╝   ╚═══╝ ╚═╝ ╚═╝"
  ui_print " "
}

# Fetch metadata from module.prop & device properties
MODNAME=$(grep_prop name "$MODPATH/module.prop")
MODVER=$(grep_prop version "$MODPATH/module.prop")
MODAUTH=$(grep_prop author "$MODPATH/module.prop")
DEVICE=$(getprop ro.product.device)
ANDROID=$(getprop ro.build.version.release)

# Detect Root Environment
if [ "$KSU" = "true" ]; then
  ROOT_ENV="KernelSU ($KSU_VER)"
elif [ "$APATCH" = "true" ]; then
  ROOT_ENV="APatch ($APATCH_VER)"
elif [ "$BOOTMODE" = "true" ]; then
  ROOT_ENV="Magisk ($MAGISK_VER)"
else
  ROOT_ENV="Custom Recovery"
fi

# Start Installation UI
twrp_progress 0.10
ui_banner

ui_print "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ui_print "  • Module     : $MODNAME"
ui_print "  • Version    : $MODVER"
ui_print "  • Author     : $MODAUTH"
ui_print "  • Device     : $DEVICE ($ARCH)"
ui_print "  • Android    : $ANDROID"
ui_print "  • Manager    : $ROOT_ENV"
ui_print "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ui_print " "

# Step 1: Configuration Menu via Volume Keys
twrp_progress 0.30
ui_print "  [1/3] Select Default IP Rotation Engine:"
ui_print "        [Vol+] WireGuard Mode (.conf Rotator)"
ui_print "        [Vol-] Tor / Orbot Mode (ControlPort 9051)"
ui_print " "

if chooseport; then
  PROFILE="WIREGUARD"
  ui_print "  [✓] Selected: WireGuard Mode"
else
  PROFILE="TOR"
  ui_print "  [✓] Selected: Tor / Orbot Mode"
fi
ui_print "  [███████░░░░░░░░░░░░░] 35%"
ui_print " "
sleep 0.3

# Step 2: Apply Module Files & Settings
twrp_progress 0.70
ui_print "  [2/3] Installing IP rotator configs & directories..."

mkdir -p "$WG_DIR"
echo "$PROFILE" > "$CONFIG_DIR/mode.conf"
sed -i "s/^MODE=.*/MODE=\"$PROFILE\"/" "$MODPATH/action.sh"

cat << 'EOF' > "$CONFIG_DIR/README.txt"
==================================================
   PUBLIC IP ROTATOR - QUICK SETUP GUIDE
   Author: hiruko-puppetmaster
==================================================

1. USING WIREGUARD MODE (Fastest Speeds)
--------------------------------------------------
- Download 5 to 10 free WireGuard (.conf) files from:
  * ProtonVPN (Free tier offers US, NL, JP, RO, PL)
  * Cloudflare WARP (generated via wgcf)
  * Any commercial VPN provider (Mullvad, IVPN, etc.)
- Copy all .conf files into:
  /data/adb/ip_rotator/wg_configs/
- Make sure the "WireGuard" app (with command-line tools enabled)
  or a "wg-quick" binary module is installed on your system.
- Tap the "Action" button in KernelSU-Next Manager to switch to a random server!

2. USING TOR / ORBOT MODE (Infinite IPs)
--------------------------------------------------
- Install Orbot (enable VPN/Root mode) and enable Control Port 9051 in settings.
- Tap the "Action" button in KernelSU-Next Manager to force a new Tor circuit (NEWNYM).
- Note: You can switch modes anytime by editing /data/adb/ip_rotator/mode.conf
  or changing MODE="WIREGUARD" / MODE="TOR" in action.sh.
EOF

if [ "$PROFILE" = "WIREGUARD" ] && ! command -v wg-quick >/dev/null 2>&1; then
  ui_print "  [!] Note: 'wg-quick' not found in PATH yet."
  ui_print "      Enable CLI tools in the WireGuard app."
fi

ui_print "  [██████████████░░░░░░] 70%"
ui_print " "
sleep 0.3

# Step 3: Set Permissions
twrp_progress 0.90
ui_print "  [3/3] Setting default permissions..."
set_perm_recursive "$MODPATH" 0 0 0755 0644
set_perm "$MODPATH/action.sh" 0 0 0755
chmod -R 0700 "$CONFIG_DIR"
ui_print "  [████████████████████] 100%"
ui_print " "

twrp_progress 1.00
ui_print "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ui_print "  ✔ Installation Complete! ($PROFILE)"
ui_print "  • WG Configs : $WG_DIR"
ui_print "  ↻ Reboot your device to apply changes."
ui_print "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ui_print " "
