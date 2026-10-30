#!/usr/bin/env bash
# Builds and installs the Substrate wallpaper (KDE Plasma 6) for the current user. No root needed.
#
#   ./install.sh            build and install
#   ./install.sh -y         no questions: build, install and restart Plasma
#   ./uninstall.sh          (or ./install.sh --uninstall)
set -euo pipefail

ID="com.github.spider19996.substrate"
SRC="$(cd "$(dirname "$0")" && pwd)"
BUILD="$SRC/build"
PKG="${XDG_DATA_HOME:-$HOME/.local/share}/plasma/wallpapers/$ID"

YES=0
for arg in "$@"; do
    case "$arg" in
    --uninstall) exec "$SRC/uninstall.sh" ;;
    -y|--yes) YES=1 ;;
    -h|--help) sed -n '2,6p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown option: $arg (see --help)"; exit 1 ;;
    esac
done

# The build also copies the plugin into contents/ui/lib, where the QML files load it from
cmake -S "$SRC" -B "$BUILD" -DCMAKE_BUILD_TYPE=Release
cmake --build "$BUILD" -j"$(nproc)"

rm -rf "$PKG"
mkdir -p "$PKG"
"$SRC/tools/build-translations.sh"
cp -r "$SRC/metadata.json" "$SRC/contents" "$PKG/"

echo "Done. To use it: right-click the desktop > Configure Desktop and Wallpaper > Wallpaper Type > Substrate"
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
