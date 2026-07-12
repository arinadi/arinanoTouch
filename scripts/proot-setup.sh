#!/data/data/com.termux/files/usr/bin/bash
# ═══════════════════════════════════════════════════════════════
# arinanoTouch — Proot Setup (atomic deployment)
#  Pull latest image, rename old to arinanotouch-prev
# ═══════════════════════════════════════════════════════════════
set -uo pipefail

CONTAINER="arinanotouch"
PREV="${CONTAINER}-prev"
GHCR_IMAGE="ghcr.io/arinadi/arinanotouch:latest"

echo ">>> arinanoTouch proot setup..."

# Backup existing as prev
if proot-distro list 2>/dev/null | grep -q "$CONTAINER"; then
    echo "  • Backing up ${CONTAINER} → ${PREV}..."
    proot-distro remove "$PREV" 2>/dev/null || true
    proot-distro rename "$CONTAINER" "$PREV"
fi

# Clear cache for fresh pull
echo "  • Clearing OCI cache..."
rm -rf ~/.termux/proot-distro/oci_layers/* 2>/dev/null || true
rm -rf ~/.termux/proot-distro/oci_manifests/* 2>/dev/null || true

# Install fresh
echo "  • Pulling ${GHCR_IMAGE}..."
proot-distro install -n "$CONTAINER" "$GHCR_IMAGE"

echo "  • Done. ${CONTAINER} ready, ${PREV} kept as backup."
echo ""
echo "  Rollback: arinanotouch rollback"
