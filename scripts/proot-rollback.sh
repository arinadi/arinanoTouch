#!/data/data/com.termux/files/usr/bin/bash
# ═══════════════════════════════════════════════════════════════
# arinanoTouch — Proot Rollback (restore prev image)
# ═══════════════════════════════════════════════════════════════
set -uo pipefail

PREV="arinanotouch-prev"

echo ">>> Rolling back to ${PREV}..."

if ! proot-distro list 2>/dev/null | grep -q "$PREV"; then
    echo "  ✗ No backup found (${PREV} missing)."
    exit 1
fi

proot-distro remove arinanotouch 2>/dev/null || true
proot-distro rename "$PREV" arinanotouch

echo "  ✓ Rolled back to ${PREV}."
