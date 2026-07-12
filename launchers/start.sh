#!/data/data/com.termux/files/usr/bin/bash
# ═══════════════════════════════════════════════════════════════
# arinanoTouch — Start (pola sama arinanoX yang working)
# ═══════════════════════════════════════════════════════════════

set -uo pipefail

echo "═══ arinanoTouch ═══"
echo ""

TMPDIR="${TMPDIR:-/data/data/com.termux/files/usr/tmp}"
SOCK="${TMPDIR}/.X11-unix/X0"
export DISPLAY=:0
export XDG_RUNTIME_DIR="$TMPDIR"

# ═══════════════════════════════════════════════════════════════
# 0. Cek PPHK
# ═══════════════════════════════════════════════════════════════
if [ -f /system/bin/device_config ]; then
    MAX_PHANTOM=$(/system/bin/device_config get activity_manager max_phantom_processes 2>/dev/null || echo "")
    if [ "$MAX_PHANTOM" != "2147483647" ]; then
        echo "⚠  Phantom Process Killer masih aktif!"
        echo "   Jalankan ADB di PC:"
        echo '   adb shell "/system/bin/device_config set_sync_disabled_for_tests persistent"'
        echo '   adb shell "/system/bin/device_config put activity_manager max_phantom_processes 2147483647"'
        echo '   adb shell settings put global settings_enable_monitor_phantom_procs false'
        echo ""
    fi
fi

# ═══════════════════════════════════════════════════════════════
# 1. Services (parallel)
# ═══════════════════════════════════════════════════════════════
echo "[1] Preload..."

# PulseAudio — timeout 2s
timeout 2 bash -c '
    pulseaudio --start --exit-idle-time=-1 2>/dev/null || true
    pactl load-module module-aaudio-sink 2>/dev/null || true
    pactl load-module module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1 port=4713 2>/dev/null || true
' 2>/dev/null || echo "  ⚠ pulse timeout"

# virgl — background, cek socket nanti pas launch
if command -v virgl_test_server_android &>/dev/null; then
    virgl_test_server_android &>/dev/null &
fi
echo "  ✓"

# ═══════════════════════════════════════════════════════════════
# 2. X11 — tanpa pkill (sama seperti arinanoX yang working)
# ═══════════════════════════════════════════════════════════════
echo "[2] X11..."

# Jangan pkill termux-x11! Biarkan yang sudah jalan dari app.
termux-x11 :0 -ac &
X11_PID=$!
termux-wake-lock

# am start di background
am start -n com.termux.x11/com.termux.x11.MainActivity &>/dev/null &

# Poll socket — 3 detik (sama seperti arinanoX)
for i in $(seq 1 30); do
    [ -S "$SOCK" ] && break
    sleep 0.1
done

if [ -S "$SOCK" ]; then
    echo "  ✓ X11 ready ($((i*100))ms)"
else
    echo "  ⚠ X11 timeout — lanjut anyway"
fi

# ═══════════════════════════════════════════════════════════════
# 3. Launch Phosh — deteksi virgl realtime
# ═══════════════════════════════════════════════════════════════
echo "[3] Phosh..."

# Deteksi virgl (cek socket)
if [ -S "${TMPDIR}/.virgl_test" ]; then
    echo "  GPU: virpipe"
    proot-distro login arinanotouch --shared-tmp -- su - admin -c "
        export DISPLAY=:0
        export XDG_RUNTIME_DIR=/tmp
        export PULSE_SERVER=tcp:127.0.0.1:4713
        export GALLIUM_DRIVER=virpipe
        export MESA_GL_VERSION_OVERRIDE=4.1COMPAT
        export MESA_GLES_VERSION_OVERRIDE=3.1
        export MESA_NO_ERROR=1
        export MESA_BACK_BUFFER=pixmap
        rm -f /tmp/dbus-* 2>/dev/null
        mkdir -p /tmp/runtime-admin
        /home/admin/.arinanotouch/launch-phosh.sh
    " || {
        echo ""
        echo "═══ Phosh error ═══"
    }
else
    echo "  GPU: software"
    proot-distro login arinanotouch --shared-tmp -- su - admin -c "
        export DISPLAY=:0
        export XDG_RUNTIME_DIR=/tmp
        export PULSE_SERVER=tcp:127.0.0.1:4713
        export LIBGL_ALWAYS_SOFTWARE=1
        rm -f /tmp/dbus-* 2>/dev/null
        mkdir -p /tmp/runtime-admin
        /home/admin/.arinanotouch/launch-phosh.sh
    " || {
        echo ""
        echo "═══ Phosh error ═══"
    }
fi

echo ""
echo "═══ arinanoTouch ended ═══"
echo "Tekan Enter..."
read -r _ 2>/dev/null || true
