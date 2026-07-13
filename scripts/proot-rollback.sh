#!/data/data/com.termux/files/usr/bin/bash
# ═══════════════════════════════════════════════════════════════
# arinanoTouch — Proot Rollback (restore prev image)
# ═══════════════════════════════════════════════════════════════
set -uo pipefail

CONTAINER="arinanotouch"
PREV="${CONTAINER}-prev"
CONTAINERS_DIR="/data/data/com.termux/files/usr/var/lib/proot-distro/containers"

echo ">>> Rolling back to ${PREV}..."

if [ ! -d "${CONTAINERS_DIR}/${PREV}" ]; then
    echo "  ✗ No backup found (${PREV} missing)."
    exit 1
fi

# Remove current
if [ -d "${CONTAINERS_DIR}/${CONTAINER}" ]; then
    echo "  • Removing current ${CONTAINER}..."
    rm -rf "${CONTAINERS_DIR}/${CONTAINER}"
fi

# Restore prev → current
echo "  • Restoring ${PREV} → ${CONTAINER}..."
mv "${CONTAINERS_DIR}/${PREV}" "${CONTAINERS_DIR}/${CONTAINER}"

echo "  ✓ Rolled back to ${PREV}."
echo "  Start: arinanotouch start"
