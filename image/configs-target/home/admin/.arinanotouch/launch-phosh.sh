#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# arinanoTouch — Inner launch (runs inside proot)
#  Openbox → Cage → Phoc → Phosh
# ═══════════════════════════════════════════════════════════════

set -uo pipefail

export PATH="${PATH:-/usr/local/bin:/usr/bin:/bin}"
export DISPLAY="${DISPLAY:-:0}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"
export PULSE_SERVER="${PULSE_SERVER:-tcp:127.0.0.1:4713}"
export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

mkdir -p "$XDG_RUNTIME_DIR"

# ── GPU ───────────────────────────────────────────────────────
if [ "${VIRGL_MODE:-}" != "none" ] && [ -S "/data/data/com.termux/files/usr/tmp/.virgl_test" ]; then
    export GALLIUM_DRIVER=virpipe
    echo "  GPU: virpipe"
else
    export LIBGL_ALWAYS_SOFTWARE=1
    echo "  GPU: software"
fi

# ── D-Bus ─────────────────────────────────────────────────────
if ! pgrep -f "dbus-daemon.*session" >/dev/null 2>&1; then
    dbus-daemon --session --fork --address="unix:path=${XDG_RUNTIME_DIR}/dbus-session" 2>/dev/null
    export DBUS_SESSION_BUS_ADDRESS="unix:path=${XDG_RUNTIME_DIR}/dbus-session"
fi

rm -f /tmp/.X*-lock /tmp/.X11-unix/* 2>/dev/null || true

# ── Verify X11 connection ─────────────────────────────────────
echo -n "  X11 check: "
if python3 -c "
import socket; s=socket.socket(socket.AF_UNIX); s.settimeout(2)
s.connect('/tmp/.X11-unix/X0')
s.send(b'l\x00\x0b\x00\x00\x00\x00\x00\x00\x00\x00\x00')
d=s.recv(8); print('OK'); s.close()
" 2>/dev/null; then
    :
else
    echo "FAIL — cannot connect to X11 socket"
    echo "  socket: $(ls /tmp/.X11-unix/X0 2>/dev/null || echo MISSING)"
    exit 1
fi

# ═══════════════════════════════════════════════════════════════
# [1] Openbox
# ═══════════════════════════════════════════════════════════════
echo ""
echo "── [1] Openbox ──"
openbox &
OPENBOX_PID=$!
sleep 1.5

if kill -0 $OPENBOX_PID 2>/dev/null; then
    echo "  ✓ Openbox running (PID $OPENBOX_PID)"
else
    echo "  ✗ Openbox DIED"
    exit 1
fi

# ═══════════════════════════════════════════════════════════════
# [2] Cage + Phoc + Phosh
# ═══════════════════════════════════════════════════════════════
echo ""
echo "── [2] Cage + Phoc + Phosh ──"
cage -- phoc -E '/usr/libexec/phosh' &
CAGE_PID=$!
sleep 3

if kill -0 $CAGE_PID 2>/dev/null; then
    echo "  ✓ Cage running (PID $CAGE_PID)"
    pgrep -x phoc >/dev/null && echo "  ✓ Phoc running"
    pgrep -x phosh >/dev/null && echo "  ✓ Phosh running"
else
    echo "  ✗ Cage DIED"

    # Check what's left
    pgrep -x phoc >/dev/null && echo "  ⚠ Phoc still running" || echo "  ✗ Phoc dead"
    pgrep -x phosh >/dev/null && echo "  ⚠ Phosh still running" || echo "  ✗ Phosh dead"

    kill $OPENBOX_PID 2>/dev/null || true
    exit 1
fi

# ═══════════════════════════════════════════════════════════════
# Wait
# ═══════════════════════════════════════════════════════════════

echo ""
echo "══════ Phosh active ══════"
echo ""

wait $CAGE_PID 2>/dev/null || true

echo ""
echo "── Phosh ended ──"
kill $OPENBOX_PID 2>/dev/null || true
exit 0
