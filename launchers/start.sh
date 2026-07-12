#!/data/data/com.termux/files/usr/bin/bash
# ═══════════════════════════════════════════════════════════════
# arinanoTouch — Start
#  Unix socket (no TCP). MIT-SHM tidak jalan lewat TCP.
#  Termux:X11 app HARUS dibuka manual sebelum script dijalankan.
# ═══════════════════════════════════════════════════════════════

set -uo pipefail
# set -e dihilangkan — script tidak akan langsung exit saat error
# agar user bisa membaca pesan error sebelum terminal close

echo "═══ arinanoTouch ═══"
echo ""

# ═══════════════════════════════════════════════════════════════
# Dependencies
# ═══════════════════════════════════════════════════════════════
SOCK="/data/data/com.termux/files/usr/tmp/.X11-unix/X0"
export DISPLAY=:0
export XDG_RUNTIME_DIR=/data/data/com.termux/files/usr/tmp

# ═══════════════════════════════════════════════════════════════
# 1. PulseAudio
# ═══════════════════════════════════════════════════════════════
echo "[1/3] PulseAudio..."
pulseaudio --start --exit-idle-time=-1 2>/dev/null || true
pactl load-module module-aaudio-sink 2>/dev/null || true
pactl load-module module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1 port=4713 2>/dev/null || true
echo "  ✓"

# ═══════════════════════════════════════════════════════════════
# 2. X11 — reuse atau start
# ═══════════════════════════════════════════════════════════════
echo "[2/3] X11..."

# Try reuse existing Termux:X11 that user manually opened
if [ -S "$SOCK" ]; then
    echo "  ✓ using existing"
else
    echo "  starting..."
    rm -rf "${XDG_RUNTIME_DIR}/.X11-unix" 2>/dev/null || true
    termux-x11 :0 -ac &
    sleep 1
    am start -n com.termux.x11/com.termux.x11.MainActivity 2>/dev/null || true

    echo -n "  waiting for socket"
    for i in $(seq 1 30); do
        [ -S "$SOCK" ] && break
        echo -n "."
        sleep 0.3
    done
    echo ""
fi

if [ -S "$SOCK" ]; then
    echo "  ✓ X11 ready"
else
    echo ""
    echo "  ✗ Gagal connect ke Termux:X11"
    echo ""
    echo "  Cara manual:"
    echo "    1. Buka Termux:X11 app dari launcher"
    echo "    2. Pastikan layar hitam muncul"
    echo "    3. Jalankan ulang script ini"
    exit 1
fi

# ═══════════════════════════════════════════════════════════════
# 3. virgl (optional)
# ═══════════════════════════════════════════════════════════════
VIRGL_MODE="none"
rm -f /data/data/com.termux/files/usr/tmp/.virgl_test 2>/dev/null

if command -v virgl_test_server_android &>/dev/null; then
    virgl_test_server_android &
    sleep 1
    [ -S /data/data/com.termux/files/usr/tmp/.virgl_test ] && VIRGL_MODE="android"
fi

# ═══════════════════════════════════════════════════════════════
# 4. Launch Phosh (Unix socket, no TCP)
# ═══════════════════════════════════════════════════════════════
echo "[3/3] Launching Phosh..."
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
    echo "═══ Phosh exited with error (code $?) ═══"
}

echo ""
echo "═══ arinanoTouch session ended ═══"
echo "Tekan Enter untuk close..."
read -r _ 2>/dev/null || true
