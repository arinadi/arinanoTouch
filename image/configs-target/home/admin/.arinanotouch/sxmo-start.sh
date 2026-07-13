#!/bin/bash
# arinanoTouch — SXMO startup wrapper (dipanggil dari host start.sh)
#
# Mengatasi:
# 1. /run/user/1000 — harus ada untuk SXMO state
# 2. DBUS_SESSION_BUS_ADDRESS — harus di-set sebelum sxmo_xinit.sh
# 3. sxhkd — lisgd tidak bisa jalan di proot (no /dev/input/touchscreen)
# 4. env vars GPU/PulseAudio — wajib untuk render + audio

set -uo pipefail

# ── Fix runtime dirs ─────────────────────────────────────────
mkdir -p /run/user/1000 2>/dev/null
chown admin:admin /run/user/1000 2>/dev/null || true

# ── Export env vars ─────────────────────────────────────────
export XDG_RUNTIME_DIR=/tmp
export PULSE_SERVER=tcp:127.0.0.1:4713
export GALLIUM_DRIVER=virpipe
export MESA_GL_VERSION_OVERRIDE=4.1COMPAT
export MESA_GLES_VERSION_OVERRIDE=3.1
export MESA_NO_ERROR=1
export MESA_BACK_BUFFER=pixmap
export NO_AT_BRIDGE=1
export DISPLAY=:0

# ── Hapus file needs-migration ──────────────────────────────
rm -f /home/admin/.config/sxmo/hooks/*.needs-migration 2>/dev/null

# ── DBUS session ────────────────────────────────────────────
# Pastikan dbus-daemon session berjalan
if ! pgrep -f 'dbus-daemon.*--session' >/dev/null 2>&1; then
    # Start new dbus session, simpan address
    dbus-launch --sh-syntax 2>/dev/null > /tmp/dbus-env
    . /tmp/dbus-env
fi
# Fallback
export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=/tmp/dbus-session}"

# ── sxhkd (pengganti lisgd) ────────────────────────────────
sxhkd -c /home/admin/.config/sxhkd/sxhkdrc &

# ── Start SXMO ─────────────────────────────────────────────
exec sxmo_xinit.sh
