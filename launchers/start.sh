#!/data/data/com.termux/files/usr/bin/bash
# ═══════════════════════════════════════════════════════════════
# arinanoTouch — Start (simple, robust)
#  User MUST open Termux:X11 app first
# ═══════════════════════════════════════════════════════════════

LOG="$HOME/arinanotouch-debug.log"
rm -f "$LOG"
log() { echo "[$(date +%H:%M:%S)] $*" | tee -a "$LOG"; }

log "═══════════════════════════════════════"
log "  arinanoTouch START"
log "═══════════════════════════════════════"

# ═══════════════════════════════════════════════════════════════
# 0. Check Termux:X11 app
# ═══════════════════════════════════════════════════════════════
SOCK="/data/data/com.termux/files/usr/tmp/.X11-unix/X0"

# Clean stale (but keep existing working socket)
for proc in pulseaudio virgl_test; do
    pids=$(pgrep -f "$proc" 2>/dev/null || true)
    [ -n "$pids" ] && { log "  killing $proc: $pids"; kill -9 $pids 2>/dev/null || true; }
done
sleep 0.5

# Don't kill existing working X11
if ! pgrep -f termux-x11 >/dev/null 2>&1; then
    log "X11 not running — starting..."
    rm -rf /data/data/com.termux/files/usr/tmp/.X11-unix 2>/dev/null || true
    rm -f /data/data/com.termux/files/usr/tmp/.X0-lock 2>/dev/null || true
    
    termux-x11 :0 -ac &
    X11_PID=$!
    log "  termux-x11 pid=$X11_PID"
    log "  ⚠ PLEASE OPEN Termux:X11 app NOW ⚠"
    
    # Wait for user to open app + socket to appear
    for i in $(seq 1 15); do
        if [ -S "$SOCK" ]; then
            log "  ✓ socket ready after ${i}s"
            break
        fi
        sleep 1
    done
else
    log "X11 already running — reusing"
fi

# Verify socket
if [ ! -S "$SOCK" ]; then
    log "✗ X11 socket NOT FOUND"
    log "  Is Termux:X11 app open?"
    log "  Open the app and re-run this script."
    exit 1
fi

# Test connection
log "testing X11 connection..."
python3 -c "
import socket
s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
s.settimeout(2)
s.connect('$SOCK')
s.close()
" 2>/dev/null && log "  ✓ X11 responsive" || log "  ⚠ X11 socket exists but no response"

# ═══════════════════════════════════════════════════════════════
# 1. PulseAudio
# ═══════════════════════════════════════════════════════════════
log ""
log "── [1] PulseAudio ──"
pulseaudio --start --exit-idle-time=-1 2>/dev/null &
sleep 0.5
pactl load-module module-aaudio-sink 2>/dev/null || true
pactl load-module module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1 port=4713 2>/dev/null || true
log "  pulseaudio ready"

# ═══════════════════════════════════════════════════════════════
# 2. virgl
# ═══════════════════════════════════════════════════════════════
log ""
log "── [2] virgl ──"
VIRGL_MODE="none"
rm -f /data/data/com.termux/files/usr/tmp/.virgl_test 2>/dev/null

if command -v virgl_test_server_android &>/dev/null; then
    virgl_test_server_android >> "$LOG" 2>&1 &
    sleep 1
    if [ -S /data/data/com.termux/files/usr/tmp/.virgl_test ]; then
        VIRGL_MODE="android"
        log "  ✓ virgl android mode"
    else
        log "  ⚠ virgl socket not created — using CPU"
    fi
else
    log "  virgl not found — using CPU"
fi

# ═══════════════════════════════════════════════════════════════
# 3. Proot + Compositor
# ═══════════════════════════════════════════════════════════════
log ""
log "── [3] Launching Phosh ──"

export DISPLAY=:0
termux-wake-lock 2>/dev/null || true

proot-distro login arinanotouch --user admin --shared-tmp -- env \
    PATH=/usr/local/bin:/usr/bin:/bin \
    DISPLAY=:0 \
    XDG_RUNTIME_DIR=/tmp \
    PULSE_SERVER=tcp:127.0.0.1:4713 \
    VIRGL_MODE="${VIRGL_MODE}" \
    HOME=/home/admin \
    SHELL=/bin/bash \
    /home/admin/.arinanotouch/launch-phosh.sh

log ""
log "── Phosh session ended ──"
log "  log: $LOG"
