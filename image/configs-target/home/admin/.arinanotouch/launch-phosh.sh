#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# arinanoTouch — Inner launch script (runs inside proot)
#  Openbox → Cage → Phoc → Phosh
# ═══════════════════════════════════════════════════════════════

set -uo pipefail

# ── Fallback values ───────────────────────────────────────────
export PATH="${PATH:-/usr/local/bin:/usr/bin:/bin}"
export DISPLAY="${DISPLAY:-:0}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"
export PULSE_SERVER="${PULSE_SERVER:-tcp:127.0.0.1:4713}"

# Ensure XDG_RUNTIME_DIR exists
mkdir -p "$XDG_RUNTIME_DIR"

export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# ── GPU setup ─────────────────────────────────────────────────
if [ "${VIRGL_MODE:-}" != "none" ] && [ -S "/data/data/com.termux/files/usr/tmp/.virgl_test" ]; then
    export GALLIUM_DRIVER=virpipe
    echo "  • GPU: virpipe (${VIRGL_MODE:-unknown})"
else
    export LIBGL_ALWAYS_SOFTWARE=1
    echo "  • GPU: software (llvmpipe)"
fi

# ── D-Bus ─────────────────────────────────────────────────────
if ! pgrep -f "dbus-daemon.*session" >/dev/null 2>&1; then
    dbus-daemon --session --fork --address="unix:path=${XDG_RUNTIME_DIR}/dbus-session"
    export DBUS_SESSION_BUS_ADDRESS="unix:path=${XDG_RUNTIME_DIR}/dbus-session"
fi

# ── Clean stale lock files ────────────────────────────────────
rm -f /tmp/.X*-lock /tmp/.X11-unix/* 2>/dev/null || true

# ═══════════════════════════════════════════════════════════════
# [3/4] Nested compositor chain
# ═══════════════════════════════════════════════════════════════

echo ""
echo ">>> [3/4] Launching compositor chain..."

# Step 1 — Openbox (MUST start first for correct resolution)
openbox &
OPENBOX_PID=$!
sleep 1.5
echo "  • Openbox: ${OPENBOX_PID}"

# Step 2 — Cage (Wayland-in-X11, sockets wlroots into X11)
#    cage -- ensures phoc args (-E, -U) are passed through correctly
cage -- phoc -E '/usr/libexec/phosh' &
CAGE_PID=$!
sleep 2
echo "  • Cage+Phoc+Phosh: ${CAGE_PID}"

# ═══════════════════════════════════════════════════════════════
# [4/4] Wait for Phosh to exit
# ═══════════════════════════════════════════════════════════════

echo ""
echo ">>> [4/4] Phosh session active"
echo "  Swipe up to unlock, enjoy."
echo ""

# Wait for cage (Phosh) to exit
wait $CAGE_PID 2>/dev/null || true

echo ">>> Phosh session ended."

# Cleanup
kill $OPENBOX_PID 2>/dev/null || true
exit 0
