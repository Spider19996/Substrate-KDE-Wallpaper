#!/usr/bin/env bash
# Removes the Substrate wallpaper (wallpaper package and QML module, user and system install).
# Your own themes in ~/.local/share/substrate-wallpaper are kept.
set -euo pipefail

ID="com.github.spider19996.substrate"
PKG="${XDG_DATA_HOME:-$HOME/.local/share}/plasma/wallpapers/$ID"
USER_QML="$HOME/.local/lib/qml"
ENV_FILE="$HOME/.config/plasma-workspace/env/substrate-qml.sh"
SYSTEM_QML="$(qmake6 -query QT_INSTALL_QML 2>/dev/null || echo /usr/lib/qt6/qml)"
MODULE="com/github/spider19996/substrate"

remove() {
    if [[ -e "$1" ]]; then
        rm -rf "$1"
        echo "Removed: $1"
    fi
}

remove "$PKG"
remove "$USER_QML/$MODULE"
remove "$ENV_FILE"

if [[ -d "$SYSTEM_QML/$MODULE" ]]; then
    sudo rm -rf "$SYSTEM_QML/$MODULE"
    echo "Removed: $SYSTEM_QML/$MODULE"
fi

echo "Substrate is uninstalled. If it is still your wallpaper, pick another wallpaper type first."
echo "Restart Plasma: systemctl --user restart plasma-plasmashell"
