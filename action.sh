#!/system/bin/sh
# ==============================================================================
# KernelSU-Next Action Script - Public IP Rotator (Wi-Fi / Cellular)
# Author: hiruko-puppetmaster
# ==============================================================================

# Default rotation mode ("WIREGUARD" or "TOR")
MODE="WIREGUARD"

# Persistent paths
BASE_DIR="/data/adb/ip_rotator"
WG_DIR="$BASE_DIR/wg_configs"
LAST_WG_FILE="$BASE_DIR/last_wg.txt"
ACTIVE_CONF="$BASE_DIR/wg0.conf"
MODE_FILE="$BASE_DIR/mode.conf"

# Override MODE if set during installation via Volume Keys
if [ -f "$MODE_FILE" ]; then
    SAVED_MODE=$(cat "$MODE_FILE" | tr -d '[:space:]')
    [ -n "$SAVED_MODE" ] && MODE="$SAVED_MODE"
fi

# Tor Control Port settings (used if MODE="TOR")
TOR_HOST="127.0.0.1"
TOR_PORT="9051"
TOR_PASS="" # Leave empty if no ControlPort password is set

# Ensure KernelSU / APatch / Magisk BusyBox and standard binaries are in PATH
export PATH="/data/adb/ksu/bin:/data/adb/ap/bin:/data/adb/magisk:/system/bin:/system/xbin:/vendor/bin:$PATH"

# Locate BusyBox for reliable applets (nc, wget, awk, sed)
BB=""
for p in /data/adb/ksu/bin/busybox /data/adb/ap/bin/busybox /data/adb/magisk/busybox; do
    if [ -x "$p" ]; then
        BB="$p"
        break
    fi
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  PUBLIC IP ROTATOR | by hiruko-puppetmaster"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  • Active Engine : $MODE"

# ------------------------------------------------------------------------------
# Helper: Fetch Public IP & Geo/ISP Details
# ------------------------------------------------------------------------------
get_public_ip() {
    RAW_JSON=""
    if command -v curl >/dev/null 2>&1; then
        RAW_JSON=$(curl -s --max-time 6 https://ipinfo.io/json 2>/dev/null)
    elif [ -n "$BB" ]; then
        RAW_JSON=$($BB wget -q -T 6 -O - https://ipinfo.io/json 2>/dev/null)
    fi

    if [ -n "$RAW_JSON" ]; then
        IP=$(echo "$RAW_JSON" | grep -o '"ip": *"[^"]*"' | cut -d'"' -f4)
        COUNTRY=$(echo "$RAW_JSON" | grep -o '"country": *"[^"]*"' | cut -d'"' -f4)
        CITY=$(echo "$RAW_JSON" | grep -o '"city": *"[^"]*"' | cut -d'"' -f4)
        ORG=$(echo "$RAW_JSON" | grep -o '"org": *"[^"]*"' | cut -d'"' -f4)
        if [ -n "$IP" ]; then
            echo "$IP ($CITY, $COUNTRY - $ORG)"
            return 0
        fi
    fi

    # Fallback to plain text endpoint
    if command -v curl >/dev/null 2>&1; then
        IP=$(curl -s --max-time 5 https://api.ipify.org 2>/dev/null)
    elif [ -n "$BB" ]; then
        IP=$($BB wget -q -T 5 -O - https://api.ipify.org 2>/dev/null)
    fi

    if [ -n "$IP" ]; then
        echo "$IP"
        return 0
    else
        echo "Unavailable (Check internet connection)"
        return 1
    fi
}

# ------------------------------------------------------------------------------
# Helper: Send Android System Notification
# ------------------------------------------------------------------------------
notify_user() {
    MSG="$1"
    su -lp 2000 -c "cmd notification post -S bigtext -t 'IP Rotated ($MODE)' 'ksu_ip_rotator' '$MSG'" >/dev/null 2>&1
}

# ------------------------------------------------------------------------------
# Step 1: Print Current Public IP
# ------------------------------------------------------------------------------
echo "  • Checking current public IP..."
OLD_IP_INFO=$(get_public_ip)
echo "  • Old IP        : $OLD_IP_INFO"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ------------------------------------------------------------------------------
# Step 2A: WireGuard Config Rotation
# ------------------------------------------------------------------------------
rotate_wireguard() {
    if ! command -v wg-quick >/dev/null 2>&1; then
        echo "  [!] ERROR: 'wg-quick' binary not found in PATH!"
        echo "      Install the WireGuard app (enable command-line tools)"
        echo "      or flash a WireGuard CLI binary module."
        exit 1
    fi

    mkdir -p "$WG_DIR"

    set -- "$WG_DIR"/*.conf
    if [ ! -e "$1" ]; then
        echo "  [!] ERROR: No WireGuard (.conf) files found!"
        echo "      Drop 5-10 .conf files (ProtonVPN / WARP) into:"
        echo "      $WG_DIR/"
        exit 1
    fi

    TOTAL_CONFIGS=$#
    LAST_USED=""
    [ -f "$LAST_WG_FILE" ] && LAST_USED=$(cat "$LAST_WG_FILE")

    echo "  [*] Found $TOTAL_CONFIGS WireGuard config(s)."

    # Tear down existing tunnel if active
    if [ -f "$ACTIVE_CONF" ] && ip link show wg0 >/dev/null 2>&1; then
        echo "  [*] Bringing down active tunnel (wg0)..."
        wg-quick down "$ACTIVE_CONF" >/dev/null 2>&1
    else
        if command -v wg >/dev/null 2>&1; then
            for iface in $(wg show interfaces 2>/dev/null); do
                echo "  [*] Bringing down active interface ($iface)..."
                wg-quick down "$iface" >/dev/null 2>&1 || ip link delete dev "$iface" 2>/dev/null
            done
        fi
    fi

    # Pick a random config without repeating the previous one
    CHOSEN_CONF=""
    ATTEMPTS=0
    while [ $ATTEMPTS -lt 10 ]; do
        ATTEMPTS=$((ATTEMPTS + 1))
        INDEX=$(( (RANDOM % TOTAL_CONFIGS) + 1 ))
        eval "CANDIDATE=\${$INDEX}"

        if [ "$TOTAL_CONFIGS" -eq 1 ] || [ "$CANDIDATE" != "$LAST_USED" ]; then
            CHOSEN_CONF="$CANDIDATE"
            break
        fi
    done
    [ -z "$CHOSEN_CONF" ] && CHOSEN_CONF="$1"

    CONF_NAME=$(basename "$CHOSEN_CONF")
    echo "$CHOSEN_CONF" > "$LAST_WG_FILE"
    echo "  [*] Selected Server : $CONF_NAME"

    # Copy to wg0.conf to avoid 15-character Linux interface name error
    cp -f "$CHOSEN_CONF" "$ACTIVE_CONF"
    chmod 600 "$ACTIVE_CONF"

    echo "  [*] Bringing up WireGuard tunnel..."
    if ! wg-quick up "$ACTIVE_CONF" >/dev/null 2>&1; then
        echo "  [!] Failed to bring up $CONF_NAME. Output:"
        wg-quick up "$ACTIVE_CONF"
        exit 1
    fi
}

# ------------------------------------------------------------------------------
# Step 2B: Tor ControlPort Circuit Reset (NEWNYM)
# ------------------------------------------------------------------------------
rotate_tor() {
    NC_CMD=""
    if [ -n "$BB" ]; then
        NC_CMD="$BB nc"
    elif command -v nc >/dev/null 2>&1; then
        NC_CMD="nc"
    else
        echo "  [!] ERROR: netcat ('nc') not found!"
        exit 1
    fi

    echo "  [*] Signaling Tor ControlPort ($TOR_HOST:$TOR_PORT)..."
    RESPONSE=$(printf 'AUTHENTICATE "%s"\r\nSIGNAL NEWNYM\r\nQUIT\r\n' "$TOR_PASS" | $NC_CMD -w 3 "$TOR_HOST" "$TOR_PORT" 2>/dev/null)

    if echo "$RESPONSE" | grep -q "250 OK"; then
        echo "  [✓] Sent SIGNAL NEWNYM! Tor exit node rotated."
    else
        echo "  [!] ERROR: Cannot reach Tor ControlPort ($TOR_HOST:$TOR_PORT)."
        echo "      1. Open Orbot and ensure VPN/Root mode is active."
        echo "      2. Enable 'Tor Control Port (9051)' in Orbot settings."
        echo "      3. Or switch to WIREGUARD in $MODE_FILE."
        exit 1
    fi
}

# ------------------------------------------------------------------------------
# Step 3: Run Selected Rotation & Verify New IP
# ------------------------------------------------------------------------------
if [ "$MODE" = "WIREGUARD" ]; then
    rotate_wireguard
elif [ "$MODE" = "TOR" ]; then
    rotate_tor
else
    echo "  [!] Unknown MODE '$MODE'. Use WIREGUARD or TOR."
    exit 1
fi

echo "  [*] Waiting 3 seconds for tunnel routing to settle..."
sleep 3

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
NEW_IP_INFO=$(get_public_ip)
echo "  ✔ New IP : $NEW_IP_INFO"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

notify_user "New IP: $NEW_IP_INFO"
exit 0
