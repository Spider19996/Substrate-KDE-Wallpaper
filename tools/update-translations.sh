#!/usr/bin/env bash
# Extracts the texts of the QML files into po/substrate.pot and merges the new texts into every po/*.po.
# Needs gettext (xgettext, msgmerge).
set -euo pipefail
cd "$(dirname "$0")/.."

DOMAIN=plasma_wallpaper_com.github.spider19996.substrate

xgettext --from-code=UTF-8 -L JavaScript --no-location --sort-output \
    -ki18nd:2 -ki18ndc:2c,3 -ki18ndp:2,3 -kN_:1 \
    --package-name=substrate-wallpaper --msgid-bugs-address="" \
    -o po/substrate.pot contents/ui/*.qml contents/ui/*.js

for po in po/*.po; do
    [ -e "$po" ] || continue
    msgmerge --quiet --update --backup=none --no-location "$po" po/substrate.pot
done
echo "Updated po/substrate.pot and $(ls po/*.po 2>/dev/null | wc -l) translations ($DOMAIN)"
