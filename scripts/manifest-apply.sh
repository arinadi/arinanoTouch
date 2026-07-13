#!/data/data/com.termux/files/usr/bin/bash
# ═══════════════════════════════════════════════════════════════
# arinanoTouch — Manifest Apply
# Reads user-manifest.yaml, installs packages, restores dotfiles
# Called automatically after `arinanotouch update`
# ═══════════════════════════════════════════════════════════════
set -euo pipefail

MANIFEST="$HOME/.arinanotouch/user-manifest.yaml"
ROOTFS="/data/data/com.termux/files/usr/var/lib/proot-distro/containers/arinanotouch/rootfs"
BACKUP_DIR="/sdcard/arinanotouch-backup"

if [ ! -f "$MANIFEST" ]; then
    echo "  • No user-manifest.yaml — skipping user layer"
    exit 0
fi

echo ">>> Applying user manifest..."

# ── Install packages ────────────────────────────────────────
if grep -q "^packages:" "$MANIFEST" 2>/dev/null; then
    PKGS=$(sed -n '/^packages:/,/^[a-z]/p' "$MANIFEST" | grep -E "^\s+- " | sed 's/^\s*- //' | grep -v "^#" | tr '\n' ' ')
    PKGS=$(echo "$PKGS" | xargs)  # trim
    
    if [ -n "$PKGS" ]; then
        echo "  Installing: $PKGS"
        proot-distro login arinanotouch -- bash -c "
            sudo apt-get update -qq 2>/dev/null
            for pkg in $PKGS; do
                echo \"    → \$pkg\"
                sudo apt-get install -y -qq \"\$pkg\" 2>/dev/null || echo \"    ⚠ skipped: \$pkg\"
            done
        " || true
        echo "  ✓ Packages installed"
    else
        echo "  • No packages in manifest"
    fi
fi

# ── Restore SXMO configs ────────────────────────────────────
CONFIG_DIR="$HOME/.arinanotouch/snapshot-current/home/.config/sxmo"
TARGET_DIR="$ROOTFS/home/admin/.config/sxmo"

if [ -d "$CONFIG_DIR" ]; then
    echo "  Restoring SXMO configs..."
    mkdir -p "$TARGET_DIR"
    cp -r "$CONFIG_DIR/"* "$TARGET_DIR/" 2>/dev/null || true
            echo "    → $xml"
        fi
    done
    echo "  ✓ Configs restored"
fi

# ── Restore dotfiles from backup ────────────────────────────
if [ -d "$BACKUP_DIR/home" ]; then
    echo "  Restoring dotfiles from backup..."
    for df in .bashrc .bash_aliases .gitconfig .config/gtk-3.0/gtk.css; do
        src="$BACKUP_DIR/home/$df"
        dest="$ROOTFS/home/admin/$df"
        if [ -f "$src" ]; then
            mkdir -p "$(dirname "$dest")"
            cp "$src" "$dest"
            echo "    → $df"
        fi
    done
    echo "  ✓ Dotfiles restored"
else
    echo "  • No backup found — skipping dotfiles"
fi

echo ""
echo "  ✓ User manifest applied."
echo "  Start: arinanotouch start"
