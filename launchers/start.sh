#!/data/data/com.termux/files/usr/bin/bash
# ═══════════════════════════════════════════════════════════════
# arinanoTouch — Start
#  PulseAudio + X11 (parallel) → proot immediately
# ═══════════════════════════════════════════════════════════════

set -euo pipefail

echo "═══ arinanoTouch ═══"

# ── Clean stale (except X11) ──────────────────────────────────
for p in openbox cage phoc phosh virgl_test; do
    pgrep -f "$p" 2>/dev/null | xargs kill -9 2>/dev/null || true
done
sleep 0.3

# ── PulseAudio (background, before X11) ───────────────────────
pulseaudio --start --exit-idle-time=-1 2>/dev/null &
pactl load-module module-aaudio-sink 2>/dev/null || true
pactl load-module module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1 port=4713 2>/dev/null || true
echo "  ✓ PulseAudio"

# ── X11 ───────────────────────────────────────────────────────
echo -n "  X11..."
SOCK="/data/data/com.termux/files/usr/tmp/.X11-unix/X0"
export DISPLAY=:0
export XDG_RUNTIME_DIR=/data/data/com.termux/files/usr/tmp

# Start X11 ONLY if not already running with socket
if [ ! -S "$SOCK" ]; then
    rm -rf "${XDG_RUNTIME_DIR}/.X11-unix" 2>/dev/null || true
    termux-x11 :0 -ac &
    sleep 1
    am start -n com.termux.x11/com.termux.x11.MainActivity 2>/dev/null || true
    for i in $(seq 1 20); do
        [ -S "$SOCK" ] && break
        sleep 0.2
    done
fi
[ -S "$SOCK" ] && echo " ✓" || { echo " ✗ FAIL"; exit 1; }

# ── virgl (optional, background) ──────────────────────────────
VIRGL_MODE="none"
rm -f /data/data/com.termux/files/usr/tmp/.virgl_test 2>/dev/null
command -v virgl_test_server_android &>/dev/null && {
    virgl_test_server_android &
    sleep 0.5
    [ -S /data/data/com.termux/files/usr/tmp/.virgl_test ] && VIRGL_MODE="android"
}

# ── Launch proot IMMEDIATELY ──────────────────────────────────
termux-wake-lock 2>/dev/null || true

echo ""
echo "═══ Launching Phosh ═══"
echo ""

proot-distro login arinanotouch --user admin --shared-tmp -- env \
    PATH=/usr/local/bin:/usr/bin:/bin \
    DISPLAY=:0 \
    XDG_RUNTIME_DIR=/tmp \
    PULSE_SERVER=tcp:127.0.0.1:4713 \
    VIRGL_MODE="${VIRGL_MODE}" \
    HOME=/home/admin \
    SHELL=/bin/bash \
    /home/admin/.arinanotouch/launch-phosh.sh

echo ""
echo "═══ Session ended ═══"
