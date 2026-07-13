#!/data/data/com.termux/files/usr/bin/bash
# ═══════════════════════════════════════════════════════════════
# arinanoTouch — Proot Setup (atomic deployment)
#  Pull latest image, backup old to arinanotouch-prev
# ═══════════════════════════════════════════════════════════════
set -uo pipefail

CONTAINER="arinanotouch"
PREV="${CONTAINER}-prev"
GHCR_IMAGE="ghcr.io/arinadi/arinanotouch:latest"
CONTAINERS_DIR="/data/data/com.termux/files/usr/var/lib/proot-distro/containers"

# ── TTY detection ────────────────────────────────────────────
if [ -t 0 ]; then
    INTERACTIVE=true
else
    INTERACTIVE=false
fi

echo ">>> arinanoTouch proot setup..."

# ── Check if container already exists ────────────────────────
CONTAINER_EXISTS=false
if [ -d "${CONTAINERS_DIR}/${CONTAINER}" ]; then
    CONTAINER_EXISTS=true
fi

if $CONTAINER_EXISTS; then
    echo "  • Container '$CONTAINER' already exists."
    echo ""
    if $INTERACTIVE; then
        echo "  [R] Redeploy — backup current, fresh pull from GHCR"
        echo "  [S] Skip     — keep current, nothing changed"
        echo ""
        read -p "  Choose [R/s]: " choice
        case "$choice" in
            [sS]|'')
                echo "  • Skipped. Current container kept."
                exit 0
                ;;
            *)
                echo "  • Redeploying..."
                ;;
        esac
    else
        # Non-interactive: default to skip
        echo "  (non-interactive — skipping redeploy)"
        echo "  To force redeploy: proot-distro remove $CONTAINER && bash $0"
        exit 0
    fi
fi

# ── Backup current → prev ────────────────────────────────────
if [ -d "${CONTAINERS_DIR}/${CONTAINER}" ]; then
    echo "  • Backing up ${CONTAINER} → ${PREV}..."
    # Remove old prev first
    if [ -d "${CONTAINERS_DIR}/${PREV}" ]; then
        rm -rf "${CONTAINERS_DIR}/${PREV}"
    fi
    # Rename current → prev (atomic: langsung rename directory)
    mv "${CONTAINERS_DIR}/${CONTAINER}" "${CONTAINERS_DIR}/${PREV}"
    echo "  • Backup saved as ${PREV}"
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
