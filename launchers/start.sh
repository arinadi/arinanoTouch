#!/data/data/com.termux/files/usr/bin/bash
# ═══════════════════════════════════════════════════════════════
# arinanoTouch — Start
#  X11 socket holder prevents XWayland timeout
# ═══════════════════════════════════════════════════════════════

set -uo pipefail

echo "═══ arinanoTouch ═══"
echo ""

SOCK="/data/data/com.termux/files/usr/tmp/.X11-unix/X0"
export DISPLAY=:0
export XDG_RUNTIME_DIR=/data/data/com.termux/files/usr/tmp

HOLDER="$(cd "$(dirname "$0")" && pwd)/x11-holder.py"

# ═══════════════════════════════════════════════════════════════
# 0. Check Phantom Process Killer
# ═══════════════════════════════════════════════════════════════
if [ -f /system/bin/device_config ]; then
    MAX_PHANTOM=$(/system/bin/device_config get activity_manager max_phantom_processes 2>/dev/null || echo "")
    if [ "$MAX_PHANTOM" != "2147483647" ]; then
        echo "⚠  Phantom Process Killer masih aktif!"
        echo "   Jalankan perintah ADB ini di PC/laptop:"
        echo ""
        echo "   adb shell \"/system/bin/device_config set_sync_disabled_for_tests persistent\""
        echo "   adb shell \"/system/bin/device_config put activity_manager max_phantom_processes 2147483647\""
        echo "   adb shell settings put global settings_enable_monitor_phantom_procs false"
        echo ""
    fi
fi

# ═══════════════════════════════════════════════════════════════
# 1. PulseAudio + virgl
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
# 2. X11 — start + holder + proot
# ═══════════════════════════════════════════════════════════════
echo "[2] X11..."

# Clean stale
pkill -9 -f termux-x11 2>/dev/null || true
sleep 0.5
rm -rf "${XDG_RUNTIME_DIR}/.X11-unix" 2>/dev/null || true
rm -f "${XDG_RUNTIME_DIR}/.X0-lock" 2>/dev/null || true
rm -f "${SOCK}.holder" 2>/dev/null || true

termux-x11 :0 -ac &
sleep 1
am start -n com.termux.x11/com.termux.x11.MainActivity 2>/dev/null || true

# Poll for socket — start holder to keep it alive
for i in $(seq 1 60); do
    if [ -S "$SOCK" ]; then
        echo "  socket ready → attaching holder..."

        # Start holder to prevent XWayland timeout
        python3 "$HOLDER" "$SOCK" &
        HOLDER_PID=$!

        # Wait for holder to connect (check for .holder marker file)
        for h in $(seq 1 20); do
            [ -f "${SOCK}.holder" ] && break
            sleep 0.1
        done

        echo "  launching..."
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

        # Clean up holder
        kill $HOLDER_PID 2>/dev/null || true
        rm -f "${SOCK}.holder" 2>/dev/null || true

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
