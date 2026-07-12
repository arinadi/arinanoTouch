# ═══════════════════════════════════════════════════════════════
# arinanoTouch — ~/.bashrc
# ═══════════════════════════════════════════════════════════════

# ──── PATH ────────────────────────────────────────────────
export PATH="$HOME/.arinanotouch/tools:$PATH"

# ──── arinanoTouch TAPI utilities ─────────────────────────
if [ -f "$HOME/.arinanotouch/tools/tapi-utils.sh" ]; then
    echo ""
    echo "╔═══════════════════════════════════╗"
    echo "║  📱 arinanoTouch — Ready         ║"
    echo "╠═══════════════════════════════════╣"
    echo "║  battery       clipget / clipset ║"
    echo "║  vol-up/down   bright 50         ║"
    echo "║  toast 'msg'   buzz              ║"
    echo "║  speak 'text'  listen            ║"
    echo "║  whereami      wifi | photo pic  ║"
    echo "╚═══════════════════════════════════╝"
    echo ""
fi

export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
