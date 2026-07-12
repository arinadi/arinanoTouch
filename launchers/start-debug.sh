#!/data/data/com.termux/files/usr/bin/bash
# ═══════════════════════════════════════════════════════════════
# arinanoTouch — DEBUG START
#  Runs step-by-step, logs everything to ~/arinanotouch-debug.log
#  Does NOT exit on error — continues and logs what failed
# ═══════════════════════════════════════════════════════════════

LOG="$HOME/arinanotouch-debug.log"
rm -f "$LOG"

log() { echo "[$(date +%H:%M:%S)] $*" | tee -a "$LOG"; }
run()  { log "RUN: $*"; "$@" >> "$LOG" 2>&1; local rc=$?; log "  → exit=$rc"; return $rc; }
run_bg() { log "BG: $*"; "$@" >> "$LOG" 2>&1 & log "  → pid=$!"; }

log "═══════════════════════════════════════"
log "  arinanoTouch DEBUG START"
log "═══════════════════════════════════════"

# ═══════════════════════════════════════════════════════════════
# 0. Clean stale
# ═══════════════════════════════════════════════════════════════
log ""
log "── [0] Clean stale ──"

for proc in termux-x11 pulseaudio virgl_test openbox cage phoc phosh; do
    pids=$(pgrep -f "$proc" 2>/dev/null || true)
    if [ -n "$pids" ]; then
        log "  killing $proc: $pids"
        kill -9 $pids 2>/dev/null || true
    fi
done
sleep 1

rm -rf /data/data/com.termux/files/usr/tmp/.X11-unix 2>/dev/null || true
rm -f /data/data/com.termux/files/usr/tmp/.virgl_test 2>/dev/null || true
rm -f /data/data/com.termux/files/usr/tmp/.X0-lock 2>/dev/null || true
log "  clean done"

# ═══════════════════════════════════════════════════════════════
# 1. PulseAudio
# ═══════════════════════════════════════════════════════════════
log ""
log "── [1] PulseAudio ──"

pulseaudio --start --exit-idle-time=-1 2>&1 | tee -a "$LOG"
sleep 0.5
log "  pulseaudio pid=$(pgrep -f pulseaudio 2>/dev/null || echo NONE)"

pactl load-module module-aaudio-sink 2>&1 | tee -a "$LOG" || log "  AAudio FAIL"
pactl load-module module-sles-sink 2>&1 | tee -a "$LOG" || log "  SLES FAIL"

pactl load-module module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1 port=4713 2>&1 | tee -a "$LOG" || log "  TCP bridge FAIL"

log "  sinks: $(pactl list sinks short 2>&1 | tr '\n' ' ')"

# ═══════════════════════════════════════════════════════════════
# 2. virgl GPU
# ═══════════════════════════════════════════════════════════════
log ""
log "── [2] virgl GPU ──"

VIRGL_MODE="none"

if command -v virgl_test_server_android &>/dev/null; then
    log "  found virgl_test_server_android"
    LD_LIBRARY_PATH="/data/data/com.termux/files/usr/lib" \
        virgl_test_server_android >> "$LOG" 2>&1 &
    VIRGL_PID=$!
    VIRGL_MODE="angle-vulkan"
    sleep 0.5
    log "  virgl pid=$VIRGL_PID mode=$VIRGL_MODE"
    log "  virgl socket: $(ls /data/data/com.termux/files/usr/tmp/.virgl_test 2>&1)"
else
    log "  virgl_test_server_android NOT FOUND"
fi

# ═══════════════════════════════════════════════════════════════
# 3. X11
# ═══════════════════════════════════════════════════════════════
log ""
log "── [3] X11 ──"

export DISPLAY=:0
export XDG_RUNTIME_DIR="${TMPDIR:-/data/data/com.termux/files/usr/tmp}"
log "  DISPLAY=$DISPLAY"
log "  XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR"

# Clean stale
rm -rf "${XDG_RUNTIME_DIR}/.X11-unix" 2>/dev/null || true
rm -f "${XDG_RUNTIME_DIR}/.X0-lock" 2>/dev/null || true
log "  cleaned stale socket dirs"

# Start X11
termux-x11 :0 -ac >> "$LOG" 2>&1 &
X11_PID=$!
log "  termux-x11 pid=$X11_PID"
sleep 1

# Activate app
log "  activating app..."
am start -n com.termux.x11/com.termux.x11.MainActivity >> "$LOG" 2>&1 || log "  am start FAILED"
sleep 2

# Check socket
SOCK="${XDG_RUNTIME_DIR}/.X11-unix/X0"
for i in 1 2 3 4 5; do
    if [ -S "$SOCK" ]; then
        log "  socket OK after ${i}s: $SOCK"
        break
    fi
    log "  socket not ready, retry $i..."
    sleep 1
done

if [ ! -S "$SOCK" ]; then
    log "  ✗ SOCKET STILL MISSING after 5s"
    log "  checking dir: $(ls -la "${XDG_RUNTIME_DIR}/.X11-unix/" 2>&1)"
    log "  X11 alive: $(pgrep -f termux-x11 2>/dev/null || echo DEAD)"
    log "  LAST 20 LINES OF X11 OUTPUT:"
    tail -20 "$LOG" | grep -A20 "termux-x11" | tee -a "$LOG"
else
    log "  ✓ X11 ready"
fi

termux-wake-lock 2>/dev/null || true

# ═══════════════════════════════════════════════════════════════
# 4. Proot + Compositor
# ═══════════════════════════════════════════════════════════════
log ""
log "── [4] Proot + Compositor Chain ──"

if [ ! -S "$SOCK" ]; then
    log "  ✗ ABORT: no X11 socket, cannot continue"
    log ""
    log "═══════════════════════════════════════"
    log "  DEBUG LOG: $LOG"
    log "  Check Termux:X11 app is OPEN"
    log "═══════════════════════════════════════"
    exit 1
fi

log "  launching proot session..."

proot-distro login arinanotouch --user admin --shared-tmp -- env \
    DISPLAY=:0 \
    XDG_RUNTIME_DIR=/tmp \
    PULSE_SERVER=tcp:127.0.0.1:4713 \
    VIRGL_MODE="${VIRGL_MODE}" \
    HOME=/home/admin \
    /home/admin/.arinanotouch/launch-phosh-debug.sh

log ""
log "── Phosh session ended ──"
log "  log: $LOG"
