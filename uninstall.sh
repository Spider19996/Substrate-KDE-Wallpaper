#!/usr/bin/env bash
# Removes the Substrate wallpaper. Your own themes in ~/.local/share/substrate-wallpaper are kept.
set -euo pipefail

ID="com.github.spider19996.substrate"
PKG="${XDG_DATA_HOME:-$HOME/.local/share}/plasma/wallpapers/$ID"

if [[ -e "$PKG" ]]; then
    rm -rf "$PKG"
    echo "Removed: $PKG"
fi

# Versions before 1.0.0 installed the plugin system-wide; it is not used any more
SYSTEM_QML="$(qmake6 -query QT_INSTALL_QML 2>/dev/null || echo /usr/lib/qt6/qml)"
OLD="$SYSTEM_QML/com/github/spider19996/substrate"
if [[ -d "$OLD" ]]; then
    echo "Found a plugin from an earlier install: $OLD"
    sudo rm -rf "$OLD"
    echo "Removed: $OLD"
fi

echo "Substrate is uninstalled. If it is still your wallpaper, pick another wallpaper type first."
echo "Restart Plasma: systemctl --user restart plasma-plasmashell"
