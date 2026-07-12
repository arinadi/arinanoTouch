#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

echo ">>> Installing launchers..."
DROIDDESK_DIR="$HOME/.arinanotouch"
mkdir -p ~/.shortcuts

# Remove old (v1 + v2 + v3)
rm -f ~/.shortcuts/{start,stop,update}{,-x11,-xfce,-arinanotouch,-proot}.sh 2>/dev/null || true
rm -f ~/.shortcuts/kill-{x11,proot,all}.sh 2>/dev/null || true
rm -f ~/.shortcuts/0-stop-arinanotouch.sh ~/.shortcuts/1-start-arinanotouch.sh ~/.shortcuts/2-update-arinanotouch.sh 2>/dev/null || true
rm -f ~/{start,stop,update}{,-x11,-xfce,-arinanotouch}.sh 2>/dev/null || true
rm -f ~/kill-{x11,proot,all}.sh 2>/dev/null || true

# Install branded shortcuts (ordered, update NOT included — destructive)
cp "${DROIDDESK_DIR}/launchers/stop.sh"   ~/.shortcuts/0-stop-arinanotouch.sh
cp "${DROIDDESK_DIR}/launchers/start.sh"  ~/.shortcuts/1-start-arinanotouch.sh
chmod +x ~/.shortcuts/0-stop-arinanotouch.sh
chmod +x ~/.shortcuts/1-start-arinanotouch.sh

# Home convenience symlinks
ln -sf ~/.shortcuts/0-stop-arinanotouch.sh   ~/stop.sh
ln -sf ~/.shortcuts/1-start-arinanotouch.sh  ~/start.sh

echo ">>> Launchers installed."
