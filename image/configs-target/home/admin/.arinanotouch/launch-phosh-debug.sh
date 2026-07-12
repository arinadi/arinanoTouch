#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# arinanoTouch — Inner launch DEBUG (runs inside proot)
#  Logs everything to /tmp/arinanotouch-inner.log
# ═══════════════════════════════════════════════════════════════

LOG="/tmp/arinanotouch-inner.log"
rm -f "$LOG"

log() { echo "[INNER $(date +%H:%M:%S)] $*" | tee -a "$LOG"; }

log "═══════════════════════════════════════"
log "  arinanoTouch INNER DEBUG"
log "═══════════════════════════════════════"

# ── Environment ──────────────────────────────────────────
export DISPLAY="${DISPLAY:-:0}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"
export PULSE_SERVER="${PULSE_SERVER:-tcp:127.0.0.1:4713}"
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export HOME=/home/admin

mkdir -p "$XDG_RUNTIME_DIR"

log "DISPLAY=$DISPLAY"
log "XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR"
log "PULSE_SERVER=$PULSE_SERVER"
log "HOME=$HOME"
log "USER=$(whoami)"
log "PID=$$"

# ── Check X11 socket ─────────────────────────────────────
if [ -S "/tmp/.X11-unix/X0" ]; then
    log "✓ X11 socket: /tmp/.X11-unix/X0"
else
    log "✗ X11 socket MISSING"
    ls -la /tmp/.X11-unix/ >> "$LOG" 2>&1 || log "  dir not found"
fi

# ── GPU ──────────────────────────────────────────────────
VIRGL_SOCK="/data/data/com.termux/files/usr/tmp/.virgl_test"
if [ "${VIRGL_MODE:-none}" != "none" ] && [ -S "$VIRGL_SOCK" ]; then
    export GALLIUM_DRIVER=virpipe
    log "GPU: virpipe (${VIRGL_MODE})"
else
    export LIBGL_ALWAYS_SOFTWARE=1
    log "GPU: software (llvmpipe), virgl socket: $(ls $VIRGL_SOCK 2>&1)"
fi

# ── DBus ─────────────────────────────────────────────────
log "checking DBus..."
if ! pgrep -f "dbus-daemon.*session" >/dev/null 2>&1; then
    dbus-daemon --session --fork --address="unix:path=${XDG_RUNTIME_DIR}/dbus-session" >> "$LOG" 2>&1
    export DBUS_SESSION_BUS_ADDRESS="unix:path=${XDG_RUNTIME_DIR}/dbus-session"
    log "  started dbus-daemon"
else
    log "  dbus already running"
fi

# ── Clean locks ──────────────────────────────────────────
rm -f /tmp/.X*-lock /tmp/.X11-unix/* 2>/dev/null || true

# ═══════════════════════════════════════════════════════════
# Step 1: Openbox
# ═══════════════════════════════════════════════════════════
log ""
log "── [1] Openbox ──"

openbox >> "$LOG" 2>&1 &
OB_PID=$!
sleep 1.5

if kill -0 $OB_PID 2>/dev/null; then
    log "✓ openbox pid=$OB_PID"
else
    log "✗ openbox DIED — check log"
    tail -10 "$LOG" | grep -i "error\|fail\|openbox" | tee -a "$LOG"
fi

# ═══════════════════════════════════════════════════════════
# Step 2: Cage → Phoc → Phosh
# ═══════════════════════════════════════════════════════════
log ""
log "── [2] Cage + Phoc + Phosh ──"

cage -d -- phoc -E /usr/libexec/phosh >> "$LOG" 2>&1 &
CAGE_PID=$!
sleep 3

if kill -0 $CAGE_PID 2>/dev/null; then
    log "✓ cage pid=$CAGE_PID"
else
    log "✗ cage DIED"
    tail -20 "$LOG" | grep -i "error\|fatal\|fail" | tee -a "$LOG"
fi

log "  phoc:  $(pgrep -x phoc 2>/dev/null || echo DEAD)"
log "  phosh: $(pgrep -x phosh 2>/dev/null || echo DEAD)"

# ═══════════════════════════════════════════════════════════
# Wait
# ═══════════════════════════════════════════════════════════
log ""
log "── Phosh session active ──"
log "  Swipe up to unlock"
log "  Full log: $LOG"
log ""

# Tail log to stdout for visibility
tail -f "$LOG" 2>/dev/null &
TAIL_PID=$!

wait $CAGE_PID 2>/dev/null || true

kill $TAIL_PID 2>/dev/null || true
kill $OB_PID 2>/dev/null || true
log "── Phosh session ended ──"
exit 0
