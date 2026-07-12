#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# arinanoTouch — Inner launch (runs inside proot, via su - admin -c)
#  Openbox → Cage → Phoc → Phosh
# ═══════════════════════════════════════════════════════════════

set -uo pipefail

export PATH="${PATH:-/usr/local/bin:/usr/bin:/bin}"
export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

echo "  XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR"
echo "  DISPLAY=$DISPLAY"
mkdir -p "${XDG_RUNTIME_DIR:-/tmp}"

# ── D-Bus ─────────────────────────────────────────────────────
if ! pgrep -f "dbus-daemon.*session" >/dev/null 2>&1; then
    dbus-daemon --session --fork --address="unix:path=${XDG_RUNTIME_DIR}/dbus-session" 2>/dev/null
    export DBUS_SESSION_BUS_ADDRESS="unix:path=${XDG_RUNTIME_DIR}/dbus-session"
fi

rm -f /tmp/.X*-lock /tmp/.X11-unix/* 2>/dev/null || true

# ═══════════════════════════════════════════════════════════════
# Verify X11
# ═══════════════════════════════════════════════════════════════
echo -n "  X11: "
if python3 -c "
import socket; s=socket.socket(socket.AF_UNIX); s.settimeout(2)
s.connect('/tmp/.X11-unix/X0')
s.send(b'l\x00\x0b\x00\x00\x00\x00\x00\x00\x00\x00\x00')
d=s.recv(8); print('OK'); s.close()
" 2>/dev/null; then
    :
else
    echo "FAIL"
    echo "  socket: $(ls /tmp/.X11-unix/X0 2>/dev/null || echo MISSING)"
    echo "  all files: $(ls /tmp/.X11-unix/ 2>/dev/null || echo dir missing)"
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
    echo "  ✓ (PID $OPENBOX_PID)"
else
    echo "  ✗ DIED"
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
    pgrep -x phoc >/dev/null && echo "  ✓ Phoc"
    pgrep -x phosh >/dev/null && echo "  ✓ Phosh"
else
    echo "  ✗ Cage DIED"
    pgrep -x phoc >/dev/null && echo "  ⚠ Phoc still up" || echo "  ✗ Phoc dead"
    pgrep -x phosh >/dev/null && echo "  ⚠ Phosh still up" || echo "  ✗ Phosh dead"
    kill $OPENBOX_PID 2>/dev/null || true
    exit 1
fi

# ═══════════════════════════════════════════════════════════════
# Active
# ═══════════════════════════════════════════════════════════════
echo ""
echo "══════ Phosh active ══════"
echo ""

wait $CAGE_PID 2>/dev/null || true

echo "── Phosh ended ──"
kill $OPENBOX_PID 2>/dev/null || true
exit 0
