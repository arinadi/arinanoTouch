#!/data/data/com.termux/files/usr/bin/bash
# ═══════════════════════════════════════════════════════════════
# arinanoTouch — Start (parallel services + Phosh desktop)
#  Openbox → Cage → Phoc → Phosh (nested compositor chain)
# ═══════════════════════════════════════════════════════════════

set -uo pipefail

# ═══════════════════════════════════════════════════════════════
# [0/4] Pre-flight: Phantom Process Killer
# ═══════════════════════════════════════════════════════════════

echo ">>> [0/4] Checking Android process limits..."
echo "  ℹ Phantom Process Killer can kill Phosh under load."
echo "    If Phosh crashes, run these via ADB:"
echo "    adb shell \"device_config set_sync_disabled_for_tests persistent\""
echo "    adb shell \"device_config put activity_manager max_phantom_processes 2147483647\""
echo "    adb shell settings put global settings_enable_monitor_phantom_procs false"
echo ""

# ═══════════════════════════════════════════════════════════════
# [1/4] Services (parallel)
# ═══════════════════════════════════════════════════════════════

echo ">>> [1/4] Starting services..."

# Kill stale processes
for pid in $(pgrep -f pulseaudio 2>/dev/null); do kill -9 "$pid" 2>/dev/null || true; done
for pid in $(pgrep -f virgl_test_server 2>/dev/null); do kill -9 "$pid" 2>/dev/null || true; done
for pid in $(pgrep -f termux-x11 2>/dev/null); do kill -9 "$pid" 2>/dev/null || true; done
sleep 0.3

# ── PulseAudio ──────────────────────────────────────────
pulseaudio --start --exit-idle-time=-1 2>/dev/null &
PA_PID=$!
sleep 0.8

# ── Load AAudio sink ────────────────────────────────────
pactl load-module module-aaudio-sink 2>/dev/null || pactl load-module module-sles-sink 2>/dev/null || true

# ── TCP bridge (proot side) ─────────────────────────────
pactl load-module module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1 port=4713 2>/dev/null || true

echo "  • PulseAudio: running"
echo "  • TCP bridge: 127.0.0.1:4713"

# ── virgl (GPU) — 2-tier: angle-vulkan → CPU ───────────
VIRGL_MODE="none"
ANGLE_DIR="/data/data/com.termux/files/usr/lib"
VIRGL_PID=""

if command -v virgl_test_server_android &>/dev/null; then
    # Tier 1 — angle-vulkan (optimal for Xclipse/RDNA2)
    LD_LIBRARY_PATH="${ANGLE_DIR}" \
        virgl_test_server_android &>/dev/null &
    VIRGL_PID=$!
    VIRGL_MODE="angle-vulkan"
    echo "  • virgl: angle-vulkan ✓"
elif command -v virgl_test_server &>/dev/null; then
    # Tier 1 fallback — plain virgl
    LD_LIBRARY_PATH="${ANGLE_DIR}" \
        virgl_test_server --use-egl-surfaceless --use-gles &>/dev/null &
    VIRGL_PID=$!
    VIRGL_MODE="angle-vulkan-null"
    echo "  • virgl: angle-vulkan-null"
else
    echo "  • virgl: not available — CPU rendering"
fi

# ── X11 ─────────────────────────────────────────────────
export DISPLAY=:0
export XDG_RUNTIME_DIR="${TMPDIR:-/data/data/com.termux/files/usr/tmp}"

# Clean stale socket dir (critical: termux-x11 fails silently if dir exists but empty)
rm -f "${TMPDIR:-/data/data/com.termux/files/usr/tmp}/.virgl_test" 2>/dev/null || true
rm -rf "${XDG_RUNTIME_DIR}/.X11-unix" "${XDG_RUNTIME_DIR}/.X0-lock" 2>/dev/null

termux-x11 :0 -ac &
X11_PID=$!
sleep 1

# Activate Termux:X11 app (required — X server needs the app activity to bind socket)
am start -n com.termux.x11/com.termux.x11.MainActivity 2>/dev/null || true
sleep 2

# Verify socket exists
if [ -S "${XDG_RUNTIME_DIR}/.X11-unix/X0" ]; then
    echo "  • X11: :0 ready"
else
    echo "  ⚠ X11 socket not found — retrying..."
    sleep 2
    [ -S "${XDG_RUNTIME_DIR}/.X11-unix/X0" ] && echo "  • X11: :0 ready" || echo "  ✗ X11 failed"
fi

# ── Wake lock ───────────────────────────────────────────
termux-wake-lock 2>/dev/null || true

# ═══════════════════════════════════════════════════════════════
# [2/4] Proot session
# ═══════════════════════════════════════════════════════════════

echo ""
echo ">>> [2/4] Launching proot..."

export -n DISPLAY XDG_RUNTIME_DIR

proot-distro login arinanotouch --user admin --shared-tmp -- env \
    DISPLAY="${DISPLAY}" \
    XDG_RUNTIME_DIR=/tmp \
    PULSE_SERVER=tcp:127.0.0.1:4713 \
    VIRGL_MODE="${VIRGL_MODE}" \
    HOME=/home/admin \
    /home/admin/.arinanotouch/launch-phosh.sh
