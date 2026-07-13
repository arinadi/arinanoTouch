#!/data/data/com.termux/files/usr/bin/bash
# ═══════════════════════════════════════════════════════════════
# arinanoTouch — Start SXMO (mobile-native X11/dwm desktop)
# ═══════════════════════════════════════════════════════════════

set -uo pipefail

echo "═══ arinanoTouch — SXMO ═══"
echo ""

TMPDIR="${TMPDIR:-/data/data/com.termux/files/usr/tmp}"
SOCK="${TMPDIR}/.X11-unix/X0"
export DISPLAY=:0
export XDG_RUNTIME_DIR="$TMPDIR"

# ═══════════════════════════════════════════════════════════════
# 0. Cek Phantom Process Killer — wajib
# ═══════════════════════════════════════════════════════════════
if [ -f /system/bin/device_config ]; then
    MAX_PHANTOM=$(/system/bin/device_config get activity_manager max_phantom_processes 2>/dev/null || echo "")
    if [ "$MAX_PHANTOM" != "2147483647" ]; then
        echo "⚠  Phantom Process Killer masih aktif!"
        echo "   SXMO bisa di-kill Android tanpa warning."
        echo "   Jalankan ADB fix dulu:"
        echo '   adb shell "/system/bin/device_config set_sync_disabled_for_tests persistent"'
        echo '   adb shell "/system/bin/device_config put activity_manager max_phantom_processes 2147483647"'
        echo '   adb shell settings put global settings_enable_monitor_phantom_procs false'
        echo ""
    fi
fi

# ═══════════════════════════════════════════════════════════════
# 1. Services (parallel)
# ═══════════════════════════════════════════════════════════════
echo "[1] Starting services..."

# PulseAudio
timeout 2 bash -c '
    pulseaudio --start --exit-idle-time=-1 2>/dev/null || true
    pactl load-module module-aaudio-sink 2>/dev/null || true
    pactl load-module module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1 port=4713 2>/dev/null || true
' 2>/dev/null || echo "  ⚠ pulse timeout"
echo "  ✓ PulseAudio"

# VirGL GPU — flag --angle-vulkan untuk Xclipse (Samsung Exynos)
if command -v virgl_test_server_android &>/dev/null; then
    echo "  • GPU: virgl_test_server_android --angle-vulkan"
    virgl_test_server_android --angle-vulkan &>/dev/null &
    sleep 0.5
elif command -v virgl_test_server &>/dev/null; then
    echo "  • GPU: virgl_test_server (fallback)"
    virgl_test_server --use-egl-surfaceless --use-gles &>/dev/null &
    sleep 0.5
else
    echo "  • GPU: software rendering (LIBGL_ALWAYS_SOFTWARE)"
fi

# ═══════════════════════════════════════════════════════════════
# 2. X11
# ═══════════════════════════════════════════════════════════════
echo "[2] X11..."

termux-x11 :0 -ac &
X11_PID=$!
termux-wake-lock

# Switch to X11 app
am start -n com.termux.x11/com.termux.x11.MainActivity &>/dev/null &

# Poll socket
for i in $(seq 1 30); do
    [ -S "$SOCK" ] && break
    sleep 0.1
done

if [ -S "$SOCK" ]; then
    echo "  ✓ X11 ready ($((i*100))ms)"
    # Holder — jaga socket tetap hidup
    HOLDER="$(cd "$(dirname "$0")" && pwd)/x11-holder.py"
    if [ -f "$HOLDER" ]; then
        python3 "$HOLDER" "$SOCK" &
        HOLDER_PID=$!
        for h in $(seq 1 10); do
            [ -f "${SOCK}.holder" ] && break
            sleep 0.1
        done
        [ -f "${SOCK}.holder" ] && echo "  ✓ holder attached (PID ${HOLDER_PID:-})" || echo "  ⚠ holder gagal start"
    fi
else
    echo "  ⚠ X11 timeout — lanjut anyway"
fi

# ═══════════════════════════════════════════════════════════════
# 3. Launch SXMO — X11/dwm native (no nested compositor)
# ═══════════════════════════════════════════════════════════════
echo "[3] SXMO..."

# Deteksi virgl
VIRGL_SOCK="${TMPDIR}/.virgl_test"
if [ -S "$VIRGL_SOCK" ]; then
    echo "  GPU: virpipe"
    proot-distro login arinanotouch --shared-tmp -- su - admin -c "
        export DISPLAY=:0
        export XDG_RUNTIME_DIR=/tmp
        export PULSE_SERVER=tcp:127.0.0.1:4713
        export NO_AT_BRIDGE=1
        export GALLIUM_DRIVER=virpipe
        export MESA_GL_VERSION_OVERRIDE=4.1COMPAT
        export MESA_GLES_VERSION_OVERRIDE=3.1
        export MESA_NO_ERROR=1
        export MESA_BACK_BUFFER=pixmap
        rm -f /tmp/dbus-* 2>/dev/null
        mkdir -p /tmp/runtime-admin
        bash ~/.arinanotouch/sxmo-start.sh
    "
else
    echo "  GPU: software"
    proot-distro login arinanotouch --shared-tmp -- su - admin -c "
        export DISPLAY=:0
        export XDG_RUNTIME_DIR=/tmp
        export PULSE_SERVER=tcp:127.0.0.1:4713
        export NO_AT_BRIDGE=1
        export LIBGL_ALWAYS_SOFTWARE=1
        bash ~/.arinanotouch/sxmo-start.sh
    "
fi

# Cleanup
kill "${HOLDER_PID:-}" 2>/dev/null || true
rm -f "${SOCK}.holder" 2>/dev/null || true

echo ""
echo "═══ arinanoTouch ended ═══"
if [ -t 0 ]; then
    echo "Tekan Enter..."
    read -r _ 2>/dev/null || true
fi
