#!/data/data/com.termux/files/usr/bin/bash
# ═══════════════════════════════════════════
#  arinanoTouch Status — Silverblue-style system overview
#  Usage: bash ~/.arinanotouch/scripts/status.sh
# ═══════════════════════════════════════════

ARINANOX_DIR="$HOME/.arinanotouch"
CONTAINER="arinanotouch"
PREV_CONTAINER="arinanotouch-prev"
ROOTFS="/data/data/com.termux/files/usr/var/lib/proot-distro/containers/${CONTAINER}/rootfs"

echo "╔═══════════════════════════════════════╗"
echo "║  📱 arinanoTouch System Status           ║"
echo "╠═══════════════════════════════════════╣"

# Deployment status
if [ -d "$ROOTFS" ]; then
    SIZE=$(du -sh "$ROOTFS" 2>/dev/null | cut -f1)
    echo "║  Current:  arinanotouch ($SIZE)"
else
    echo "║  Current:  NOT INSTALLED"
fi

# Rollback deployment
PREV_ROOTFS="/data/data/com.termux/files/usr/var/lib/proot-distro/containers/${PREV_CONTAINER}/rootfs"
if [ -d "$PREV_ROOTFS" ]; then
    SIZE=$(du -sh "$PREV_ROOTFS" 2>/dev/null | cut -f1)
    echo "║  Rollback: arinanotouch-prev ($SIZE)"
fi

echo "╠═══════════════════════════════════════╣"

# Running status
if pgrep -f "xfce4-session" > /dev/null 2>&1; then
    echo "║  ● XFCE session running"
else
    echo "║  ○ XFCE not running"
fi

if pgrep -f "termux.x11" > /dev/null 2>&1; then
    echo "║  ● X11 server running"
else
    echo "║  ○ X11 server not running"
fi

echo "╠═══════════════════════════════════════╣"

# Layered packages
if [ -f "$ARINANOX_DIR/layers.txt" ]; then
    COUNT=$(wc -l < "$ARINANOX_DIR/layers.txt")
    echo "║  Layered:  $COUNT packages"
    echo "║  (bash ~/.arinanotouch/scripts/patch.sh)"
else
    echo "║  Layered:  0 (use patch.sh to add)"
fi

# Disk usage
BACKUP_DIR="$ARINANOX_DIR/backups"
if [ -d "$BACKUP_DIR" ]; then
    BACKUP_COUNT=$(ls "$BACKUP_DIR"/home-*.tar.gz 2>/dev/null | wc -l)
    if [ "$BACKUP_COUNT" -gt 0 ]; then
        BACKUP_SIZE=$(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1)
        echo "║  Backups:  ${BACKUP_COUNT} snapshots ($BACKUP_SIZE)"
    fi
fi

echo "╚═══════════════════════════════════════╝"
echo ""
echo "  Update:  bash ~/update.sh"
echo "  Rollback: bash ~/.arinanotouch/scripts/proot-rollback.sh"
echo "  Status:  bash ~/.arinanotouch/scripts/status.sh"
