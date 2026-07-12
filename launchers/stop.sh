#!/data/data/com.termux/files/usr/bin/bash
# ═══════════════════════════════════════════════════════════════
# arinanoTouch — Stop (kill all components)
# ═══════════════════════════════════════════════════════════════

echo ">>> Stopping arinanoTouch..."

# ── Phosh/Phoc/Cage/Openbox (inside proot) ────────────────────
echo "  [*] Killing compositor chain..."
for proc in phosh phoc cage openbox squeekboard; do
    pkill -f "$proc" 2>/dev/null && echo "  [x] $proc" || true
done
sleep 1
for proc in phosh phoc cage openbox squeekboard; do
    pkill -9 -f "$proc" 2>/dev/null || true
done

# ── Proot sessions ────────────────────────────────────────────
echo "  [*] Killing proot sessions..."
pkill -f "dbus-daemon --nofork --session" 2>/dev/null && echo "  [x] dbus-daemon" || true
pkill -f "proot-distro login arinanotouch" 2>/dev/null && echo "  [x] proot login" || true
pkill -f "proot.*installed-rootfs/arinanotouch" 2>/dev/null && echo "  [x] orphan proot" || true
sleep 0.5
pkill -9 -f "proot.*installed-rootfs/arinanotouch" 2>/dev/null || true

# ── Clean temp files (inside proot) ───────────────────────────
ROOTFS="/data/data/com.termux/files/usr/var/lib/proot-distro/containers/arinanotouch/rootfs"
if [ -d "$ROOTFS" ]; then
    echo "  [*] Cleaning temp files..."
    rm -rf "$ROOTFS/tmp/"{.X*,dbus-*,ssh-*,xdg-*} 2>/dev/null || true
    rm -f "$ROOTFS/tmp/.dbus"* 2>/dev/null || true
    rm -rf "$ROOTFS/home/admin/.cache/"* 2>/dev/null || true
fi

# ── virgl server ──────────────────────────────────────────────
pkill -f "virgl_test_server" 2>/dev/null && echo "  [x] virgl server" || true

# ── X11 ───────────────────────────────────────────────────────
echo "  [*] Stopping X11..."
pkill -f "termux-x11" 2>/dev/null && echo "  [x] termux-x11" || echo "  [-] X11 not running"
pkill -9 -f "termux-x11" 2>/dev/null || true
TMPDIR="${TMPDIR:-/data/data/com.termux/files/usr/tmp}"
rm -f "${TMPDIR}/.X0-lock" 2>/dev/null || true
rm -rf "${TMPDIR}/.X11-unix" 2>/dev/null || true

# ── PulseAudio ────────────────────────────────────────────────
echo "  [*] Stopping PulseAudio..."
pulseaudio --kill 2>/dev/null && echo "  [x] pulseaudio" || pkill -9 pulseaudio 2>/dev/null || true

# ── Wake lock ─────────────────────────────────────────────────
termux-wake-unlock 2>/dev/null || true

echo ">>> arinanoTouch stopped. ✓"
