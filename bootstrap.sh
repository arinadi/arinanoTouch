#!/data/data/com.termux/files/usr/bin/bash
# ═══════════════════════════════════════════════════════════════
# arinanoTouch — Bootstrap (one-command install)
# Debian 13 + SXMO (dwm) mobile shell in Termux proot
# ═══════════════════════════════════════════════════════════════
set -uo pipefail

# ── Detect interactive vs pipe ────────────────────────────────
if [ -t 0 ]; then
    INTERACTIVE=true
else
    INTERACTIVE=false
fi

echo "╔══════════════════════════════════════════════════════╗"
echo "║  📱 arinanoTouch — SXMO on Termux                  ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

CONTAINER="arinanotouch"
GHCR_IMAGE="ghcr.io/arinadi/arinanotouch:latest"
SCRIPTS_DIR="${HOME}/.arinanotouch/scripts"
BIN_DIR="${HOME}/.arinanotouch/bin"

# ═══════════════════════════════════════════════════════════════
# Pre-flight checks
# ═══════════════════════════════════════════════════════════════

echo ">>> [0/4] Pre-flight checks..."

# ── Android version ──────────────────────────────────────────
ANDROID_VERSION=$(getprop ro.build.version.sdk 2>/dev/null || echo "0")
if [ "$ANDROID_VERSION" -lt 31 ] 2>/dev/null; then
    echo ""
    echo "  ⚠ WARNING: Android 12+ recommended for GPU acceleration."
    echo "  Your device: Android SDK $ANDROID_VERSION"
    echo "  SXMO WILL run but with software rendering only (slow)."
    echo ""
    if $INTERACTIVE; then
        echo "  Continue anyway? (y/n)"
        read -r confirm
        [ "$confirm" != "y" ] && echo "Aborted." && exit 0
    else
        echo "  (non-interactive — continuing with software rendering)"
    fi
fi

# ── Phantom Process Killer — wajib fix, bukan sekedar catatan ─
if [ "$ANDROID_VERSION" -ge 31 ] 2>/dev/null; then
    echo "  • Phantom Process Killer check..."
    MAX_PHANTOM=$(/system/bin/device_config get activity_manager max_phantom_processes 2>/dev/null || echo "")
    if [ "$MAX_PHANTOM" != "2147483647" ]; then
        echo ""
        echo "  ⚠ Phantom Process Killer masih aktif!"
        echo "  SXMO bisa di-kill Android tanpa warning jika ini tidak di-fix."
        echo ""
        echo "  Jalankan ADB dari PC/Laptop:"
        echo ""
        echo '    adb shell "/system/bin/device_config set_sync_disabled_for_tests persistent"'
        echo '    adb shell "/system/bin/device_config put activity_manager max_phantom_processes 2147483647"'
        echo '    adb shell settings put global settings_enable_monitor_phantom_procs false'
        echo ""
        echo "  Atau: Settings → Developer Options → Disable child process restrictions"
        echo ""
        if $INTERACTIVE; then
            echo "  Abort? (y/n)"
            read -r confirm
            [ "$confirm" != "n" ] && echo "Aborted." && exit 1
        else
            echo "  (non-interactive — continuing anyway, SXMO may be killed under load)"
        fi
    else
        echo "  ✓ Phantom Killer sudah di-fix"
    fi
fi

# ── GPU: VirGL + ANGLE check ─────────────────────────────────
echo "  • GPU check..."
GPU_OK=false
if command -v virgl_test_server_android &>/dev/null; then
    echo "  ✓ virgl_test_server_android tersedia"
    GPU_OK=true
else
    echo "  ⚠ virgl_test_server_android tidak ditemukan."
    echo "    Akan diinstal via host-setup."
fi

# ── Dependencies ──────────────────────────────────────────────
echo "  • Checking Termux dependencies..."
DEPS=("proot-distro" "pulseaudio" "termux-x11")
MISSING=()
for dep in "${DEPS[@]}"; do
    if ! command -v "$dep" &>/dev/null; then
        MISSING+=("$dep")
    fi
done

if [ ${#MISSING[@]} -gt 0 ]; then
    echo "  Installing missing: ${MISSING[*]}"
    pkg install -y "${MISSING[@]}" 2>/dev/null || {
        echo "  ⚠ Could not auto-install. Manually run:"
        echo "    pkg install proot-distro pulseaudio termux-x11-nightly"
        exit 1
    }
fi

# ═══════════════════════════════════════════════════════════════
# Deploy scripts
# ═══════════════════════════════════════════════════════════════

echo ""
echo ">>> [1/4] Deploying scripts..."

mkdir -p "$SCRIPTS_DIR" "$BIN_DIR" "${HOME}/.shortcuts"

SCRIPT_BASE="${HOME}/arinanoTouch/scripts"
for f in proot-setup.sh proot-rollback.sh proot-backup.sh proot-restore.sh \
         status.sh doctor.sh seccomp-check.sh seccomp-fix.sh \
         host-setup.sh launcher-gen.sh motd-setup.sh \
         manifest-apply.sh manifest-generate.sh user-snapshot.sh; do
    cp "${SCRIPT_BASE}/${f}" "$SCRIPTS_DIR/" 2>/dev/null || true
done
cp "${SCRIPT_BASE}/arinanotouch" "$BIN_DIR/" 2>/dev/null || true

chmod +x "$SCRIPTS_DIR"/*.sh "$BIN_DIR/"* 2>/dev/null || true

echo "  ✓ Scripts deployed to ~/.arinanotouch/"

# ═══════════════════════════════════════════════════════════════
# Host setup
# ═══════════════════════════════════════════════════════════════

echo ""
echo ">>> [2/4] Host setup..."

if [ -f "${SCRIPTS_DIR}/host-setup.sh" ]; then
    bash "${SCRIPTS_DIR}/host-setup.sh"
else
    # Minimal fallback
    pkg install -y x11-repo 2>/dev/null || true
    pkg install -y termux-x11-nightly 2>/dev/null || true
    pkg install -y virglrenderer-android angle-android 2>/dev/null || true
    pkg install -y rsync 2>/dev/null || true
fi

# ═══════════════════════════════════════════════════════════════
# Deploy proot image
# ═══════════════════════════════════════════════════════════════

echo ""
echo ">>> [3/4] Deploying proot image..."

if [ -f "${SCRIPTS_DIR}/proot-setup.sh" ]; then
    bash "${SCRIPTS_DIR}/proot-setup.sh"
else
    echo "  Pulling from GHCR..."
    proot-distro remove "$CONTAINER" 2>/dev/null || true
    rm -rf ~/.termux/proot-distro/oci_layers/* 2>/dev/null || true
    rm -rf ~/.termux/proot-distro/oci_manifests/* 2>/dev/null || true
    proot-distro install -n "$CONTAINER" "$GHCR_IMAGE"
fi

# ═══════════════════════════════════════════════════════════════
# Generate launchers (Termux:Widget)
# ═══════════════════════════════════════════════════════════════

echo ""
echo ">>> [4/4] Generating launchers..."

cp "${HOME}/arinanoTouch/launchers/start.sh" "${HOME}/.shortcuts/1-start-arinanotouch.sh" 2>/dev/null || true
cp "${HOME}/arinanoTouch/launchers/stop.sh" "${HOME}/.shortcuts/0-stop-arinanotouch.sh" 2>/dev/null || true
chmod +x "${HOME}/.shortcuts/"*.sh 2>/dev/null || true

# Add CLI to PATH
if ! grep -q "arinanotouch/bin" "${HOME}/.bashrc" 2>/dev/null; then
    echo "" >> "${HOME}/.bashrc"
    echo "# arinanoTouch CLI" >> "${HOME}/.bashrc"
    echo "export PATH=\"${BIN_DIR}:\$PATH\"" >> "${HOME}/.bashrc"
fi

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║  ✅ arinanoTouch (SXMO) installed!                  ║"
echo "║                                                     ║"
echo "║  arinanotouch start      # Launch SXMO desktop      ║"
echo "║  arinanotouch stop       # Stop everything          ║"
echo "║  arinanotouch status     # System overview          ║"
echo "║  arinanotouch doctor     # Health check             ║"
echo "║  arinanotouch backup     # Backup to /sdcard        ║"
echo "║  arinanotouch help       # All commands             ║"
echo "║                                                     ║"
echo "║  Widget: 1-start-arinanotouch / 0-stop              ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
