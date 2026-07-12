#!/data/data/com.termux/files/usr/bin/bash
# ═══════════════════════════════════════════════════════════════
# arinanoTouch — MINIMAL START (no GPU, TCP X11 bridge)
# ═══════════════════════════════════════════════════════════════

set -euo pipefail

echo "═══ arinanoTouch MINIMAL ═══"
echo ""

# ── Kill stale ──────────────────────────────────────────────
echo "[0] Clean..."
for p in termux-x11 pulseaudio virgl openbox cage phoc phosh; do
    pgrep -f "$p" 2>/dev/null | xargs kill -9 2>/dev/null || true
done
sleep 1
rm -rf /data/data/com.termux/files/usr/tmp/.X11-unix 2>/dev/null || true
rm -f /data/data/com.termux/files/usr/tmp/.X0-lock 2>/dev/null || true

# ── PulseAudio ──────────────────────────────────────────────
echo "[1] PulseAudio..."
pulseaudio --start --exit-idle-time=-1 2>/dev/null
sleep 0.3
pactl load-module module-aaudio-sink 2>/dev/null || true
pactl load-module module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1 port=4713 2>/dev/null || true
echo "  ✓"

# ── X11 (Unix socket) ──────────────────────────────────────
echo "[2] X11..."
export DISPLAY=:0
export XDG_RUNTIME_DIR=/data/data/com.termux/files/usr/tmp
termux-x11 :0 -ac &
X11_PID=$!
sleep 2

# Wait for socket
for i in $(seq 1 10); do
    [ -S "${XDG_RUNTIME_DIR}/.X11-unix/X0" ] && break
    sleep 0.5
done

if [ ! -S "${XDG_RUNTIME_DIR}/.X11-unix/X0" ]; then
    echo "  ✗ X11 socket not found"
    exit 1
fi
echo "  ✓ socket ready"

# ── X11 TCP bridge (socat) ─────────────────────────────────
echo "[3] TCP bridge..."
# Bridge Unix socket → TCP so proot can reach it
socat TCP-LISTEN:6000,reuseaddr,fork UNIX-CONNECT:"${XDG_RUNTIME_DIR}/.X11-unix/X0" &
SOCAT_PID=$!
sleep 0.5
echo "  ✓ TCP bridge on :6000"

# ── Wake lock ───────────────────────────────────────────────
termux-wake-lock 2>/dev/null || true

# ── Proot ───────────────────────────────────────────────────
echo "[4] Proot + Phosh..."
echo ""

proot-distro login arinanotouch --user admin -- bash -c "
export DISPLAY=127.0.0.1:0
export PULSE_SERVER=tcp:127.0.0.1:4713
export XDG_RUNTIME_DIR=/tmp
export LANG=en_US.UTF-8
export HOME=/home/admin
export LIBGL_ALWAYS_SOFTWARE=1
mkdir -p /tmp

echo '  → Testing X11...'
python3 -c \"
import socket
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.settimeout(3)
s.connect(('127.0.0.1', 6000))
print('  ✓ X11 TCP connected')
s.close()
\" || { echo '  ✗ X11 TCP FAILED'; exit 1; }

echo '  → Starting openbox...'
openbox &
sleep 1
pgrep openbox && echo '  ✓ openbox' || { echo '  ✗ openbox failed'; exit 1; }

echo '  → Starting cage + phoc + phosh...'
# WLR_X11_NO_MITSHM=1: disable shared memory (not available over TCP)
# WLR_X11_OUTPUT: force output name for layout
WLR_X11_NO_MITSHM=1 \
    cage -d -- phoc -E /usr/libexec/phosh &
sleep 4

echo ''
echo '═══ STATUS ═══'
pgrep openbox && echo '  openbox ✓'
pgrep cage    && echo '  cage ✓'
pgrep phoc    && echo '  phoc ✓'  
pgrep phosh   && echo '  phosh ✓'
echo '═════════════════'
echo ''
echo 'Phosh active. Check Termux:X11 app.'
wait
"

# Cleanup
kill $SOCAT_PID 2>/dev/null || true
echo "Done."
