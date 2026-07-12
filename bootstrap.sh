#!/data/data/com.termux/files/usr/bin/bash
# ═══════════════════════════════════════════════════════════════
# arinanoTouch — Bootstrap (one-command install)
# Debian 13 + Phosh mobile desktop in Termux proot
# ═══════════════════════════════════════════════════════════════
set -uo pipefail

echo "╔══════════════════════════════════════════════════════╗"
echo "║  📱 arinanoTouch — Phosh on Termux                 ║"
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

# Android 12+ required for VirGL
ANDROID_VERSION=$(getprop ro.build.version.sdk 2>/dev/null || echo "0")
if [ "$ANDROID_VERSION" -lt 31 ] 2>/dev/null; then
    echo ""
    echo "  ⚠ WARNING: Android 12+ recommended for GPU acceleration."
    echo "  Your device: Android SDK $ANDROID_VERSION"
    echo "  Phosh WILL run but with software rendering only (slow)."
    echo ""
    echo "  Continue anyway? (y/n)"
    read -r confirm
    [ "$confirm" != "y" ] && echo "Aborted." && exit 0
    SOFTWARE_RENDER=true
else
    SOFTWARE_RENDER=false
fi

# Phantom Process Killer (Android 12+)
if [ "$ANDROID_VERSION" -ge 31 ] 2>/dev/null; then
    echo "  • Phantom Process Killer check..."
    echo "    If Phosh crashes/fails to start, run:"
    echo "    adb shell \"/system/bin/device_config set_sync_disabled_for_tests persistent\""
    echo "    adb shell \"/system/bin/device_config put activity_manager max_phantom_processes 2147483647\""
    echo "    adb shell settings put global settings_enable_monitor_phantom_procs false"
fi

# Check for required packages
echo "  • Checking dependencies..."
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

# Copy all scripts from repo
SCRIPT_BASE="${HOME}/arinanoTouch/scripts"
cp "${SCRIPT_BASE}/proot-setup.sh" "$SCRIPTS_DIR/" 2>/dev/null
cp "${SCRIPT_BASE}/proot-rollback.sh" "$SCRIPTS_DIR/" 2>/dev/null
cp "${SCRIPT_BASE}/proot-backup.sh" "$SCRIPTS_DIR/" 2>/dev/null
cp "${SCRIPT_BASE}/proot-restore.sh" "$SCRIPTS_DIR/" 2>/dev/null
cp "${SCRIPT_BASE}/status.sh" "$SCRIPTS_DIR/" 2>/dev/null
cp "${SCRIPT_BASE}/doctor.sh" "$SCRIPTS_DIR/" 2>/dev/null
cp "${SCRIPT_BASE}/seccomp-check.sh" "$SCRIPTS_DIR/" 2>/dev/null
cp "${SCRIPT_BASE}/seccomp-fix.sh" "$SCRIPTS_DIR/" 2>/dev/null
cp "${SCRIPT_BASE}/host-setup.sh" "$SCRIPTS_DIR/" 2>/dev/null
cp "${SCRIPT_BASE}/launcher-gen.sh" "$SCRIPTS_DIR/" 2>/dev/null
cp "${SCRIPT_BASE}/motd-setup.sh" "$SCRIPTS_DIR/" 2>/dev/null
cp "${SCRIPT_BASE}/manifest-apply.sh" "$SCRIPTS_DIR/" 2>/dev/null
cp "${SCRIPT_BASE}/manifest-generate.sh" "$SCRIPTS_DIR/" 2>/dev/null
cp "${SCRIPT_BASE}/user-snapshot.sh" "$SCRIPTS_DIR/" 2>/dev/null
cp "${SCRIPT_BASE}/arinanotouch" "$BIN_DIR/" 2>/dev/null

# Copy launchers
cp "${HOME}/arinanoTouch/launchers/start.sh" "${HOME}/start.sh" 2>/dev/null
cp "${HOME}/arinanoTouch/launchers/stop.sh" "${HOME}/stop.sh" 2>/dev/null

chmod +x "$SCRIPTS_DIR"/*.sh "$BIN_DIR/"* "${HOME}/start.sh" "${HOME}/stop.sh" 2>/dev/null || true

echo "  • Scripts deployed to ~/.arinanotouch/"

# ═══════════════════════════════════════════════════════════════
# Host setup
# ═══════════════════════════════════════════════════════════════

echo ""
echo ">>> [2/4] Host setup..."

if [ -f "${SCRIPTS_DIR}/host-setup.sh" ]; then
    bash "${SCRIPTS_DIR}/host-setup.sh"
else
    # Minimal setup
    pkg install -y x11-repo 2>/dev/null || true
    pkg install -y termux-x11-nightly 2>/dev/null || true
    pkg install -y virglrenderer-android 2>/dev/null || true
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
    # Fallback: manual pull
    echo "  Pulling from GHCR..."
    proot-distro remove "$CONTAINER" 2>/dev/null || true
    
    # Clear cache to force fresh pull
    rm -rf ~/.termux/proot-distro/oci_layers/* 2>/dev/null || true
    rm -rf ~/.termux/proot-distro/oci_manifests/* 2>/dev/null || true
    
    proot-distro install -n "$CONTAINER" "$GHCR_IMAGE"
fi

# ═══════════════════════════════════════════════════════════════
# Generate launchers (Termux:Widget)
# ═══════════════════════════════════════════════════════════════

echo ""
echo ">>> [4/4] Generating launchers..."

# Widget shortcuts (real files, not symlinks)
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
echo "║  ✅ arinanoTouch installed!                         ║"
echo "║                                                     ║"
echo "║  arinanotouch start      # Launch Phosh desktop     ║"
echo "║  arinanotouch stop       # Stop everything          ║"
echo "║  arinanotouch status     # System overview          ║"
echo "║  arinanotouch doctor     # Health check             ║"
echo "║  arinanotouch backup     # Backup to /sdcard        ║"
echo "║  arinanotouch help       # All commands             ║"
echo "║                                                     ║"
echo "║  Widget: 1-start-arinanotouch / 0-stop              ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
