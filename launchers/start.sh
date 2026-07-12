#!/data/data/com.termux/files/usr/bin/bash
# ═══════════════════════════════════════════════════════════════
# arinanoTouch — Start
#  Preload semua (PA,virgl) → X11 → proot INSTANT connect
# ═══════════════════════════════════════════════════════════════

set -uo pipefail

echo "═══ arinanoTouch ═══"
echo ""

SOCK="/data/data/com.termux/files/usr/tmp/.X11-unix/X0"
export DISPLAY=:0
export XDG_RUNTIME_DIR=/data/data/com.termux/files/usr/tmp

# ═══════════════════════════════════════════════════════════════
# 1. PulseAudio + virgl (jalankan sebelum X11, supaya gak delay)
# ═══════════════════════════════════════════════════════════════
echo "[1] Preload..."

pulseaudio --start --exit-idle-time=-1 2>/dev/null || true
pactl load-module module-aaudio-sink 2>/dev/null || true
pactl load-module module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1 port=4713 2>/dev/null || true

VIRGL_MODE="none"
rm -f /data/data/com.termux/files/usr/tmp/.virgl_test 2>/dev/null
if command -v virgl_test_server_android &>/dev/null; then
    virgl_test_server_android &
    sleep 0.5
    [ -S /data/data/com.termux/files/usr/tmp/.virgl_test ] && VIRGL_MODE="android"
fi

echo "  ✓ done"

# ═══════════════════════════════════════════════════════════════
# 2. X11 — start → INSTANT proot launch
# ═══════════════════════════════════════════════════════════════
echo "[2] X11..."

# Clean stale
pkill -9 -f termux-x11 2>/dev/null || true
sleep 0.5
rm -rf "${XDG_RUNTIME_DIR}/.X11-unix" 2>/dev/null || true
rm -f "${XDG_RUNTIME_DIR}/.X0-lock" 2>/dev/null || true

termux-x11 :0 -ac &
sleep 1
am start -n com.termux.x11/com.termux.x11.MainActivity 2>/dev/null || true

# Poll for socket — once found, LAUNCH INSTANTLY (no echo, no sleep)
for i in $(seq 1 40); do
    if [ -S "$SOCK" ]; then
        echo "  ✓ socket ready → launching..."

        termux-wake-lock 2>/dev/null || true

        proot-distro login arinanotouch --user admin --shared-tmp -- env \
            PATH=/usr/local/bin:/usr/bin:/bin \
            DISPLAY=:0 \
            XDG_RUNTIME_DIR=/tmp \
            PULSE_SERVER=tcp:127.0.0.1:4713 \
            VIRGL_MODE="${VIRGL_MODE}" \
            HOME=/home/admin \
            SHELL=/bin/bash \
            /home/admin/.arinanotouch/launch-phosh.sh || {
            echo ""
            echo "═══ Phosh error ═══"
        }

        echo ""
        echo "═══ arinanoTouch session ended ═══"
        echo "Tekan Enter..."
        read -r _ 2>/dev/null || true
        exit 0
    fi
    sleep 0.3
done

# Socket never appeared
echo ""
echo "  ✗ Socket tidak muncul"
echo ""
echo "  Perbaiki:"
echo "    1. am force-stop com.termux.x11"
echo "    2. Buka Termux:X11 app manual"
echo "    3. Tunggu layar hitam"
echo "    4. Jangan close app"
echo "Tekan Enter..."
read -r _ 2>/dev/null || true
exit 1
