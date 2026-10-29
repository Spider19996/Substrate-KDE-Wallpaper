#!/usr/bin/env bash
# Builds and installs the Substrate wallpaper (KDE Plasma 6).
#
#   ./install.sh            QML module system-wide (sudo), wallpaper package for the current user
#   ./install.sh --user     everything in the home directory only (log out and in afterwards)
#   ./install.sh -y         no questions: build, install and restart Plasma
#   ./uninstall.sh          (or ./install.sh --uninstall)
set -euo pipefail

ID="com.github.spider19996.substrate"
SRC="$(cd "$(dirname "$0")" && pwd)"
BUILD="$SRC/build"
PKG="${XDG_DATA_HOME:-$HOME/.local/share}/plasma/wallpapers/$ID"
USER_QML="$HOME/.local/lib/qml"
ENV_FILE="$HOME/.config/plasma-workspace/env/substrate-qml.sh"
SYSTEM_QML="$(qmake6 -query QT_INSTALL_QML 2>/dev/null || echo /usr/lib/qt6/qml)"
MODULE="com/github/spider19996/substrate"

MODE=system
YES=0
for arg in "$@"; do
    case "$arg" in
    --uninstall) exec "$SRC/uninstall.sh" ;;
    --user) MODE=user ;;
    -y|--yes) YES=1 ;;
    -h|--help) sed -n '2,7p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown option: $arg (see --help)"; exit 1 ;;
    esac
done

if [[ $MODE == user ]]; then
    cmake -S "$SRC" -B "$BUILD" -DCMAKE_BUILD_TYPE=Release -DSUBSTRATE_QML_DIR="$USER_QML"
else
    cmake -S "$SRC" -B "$BUILD" -DCMAKE_BUILD_TYPE=Release -DSUBSTRATE_QML_DIR=
fi
cmake --build "$BUILD" -j"$(nproc)"

if [[ $MODE == user ]]; then
    cmake --install "$BUILD"
    mkdir -p "$(dirname "$ENV_FILE")"
    echo "export QML_IMPORT_PATH=\"$USER_QML\${QML_IMPORT_PATH:+:\$QML_IMPORT_PATH}\"" > "$ENV_FILE"
    echo "Note: log out and back in once so Plasma picks up the module path."
else
    sudo cmake --install "$BUILD"
fi

rm -rf "$PKG"
mkdir -p "$PKG"
cp -r "$SRC/metadata.json" "$SRC/contents" "$PKG/"

echo "Done. To use it: right-click the desktop > Configure Desktop and Wallpaper > Wallpaper Type > Substrate"
if [[ $MODE == user ]]; then
    echo "With --user: log out and back in once so Plasma finds the module."
    exit 0
fi

echo "Plasma only loads a new version after a restart."
answer=y
if [[ $YES -eq 1 ]]; then
    answer=y
elif [[ -t 0 ]]; then
    read -r -p "Restart Plasma now (the desktop flickers briefly)? [Y/n] " answer || answer=n
else
    answer=n
fi
if [[ ! "$answer" =~ ^[nN]$ ]]; then
    systemctl --user restart plasma-plasmashell
    echo "Plasma was restarted."
else
    echo "Later: systemctl --user restart plasma-plasmashell"
fi
