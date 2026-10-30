#!/usr/bin/env bash
# Packs what is needed to build and install Substrate into dist/Substrate-KDE-Wallpaper-<version>.zip,
# for the KDE Store or for sharing. Unpack it and run ./install.sh.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="$(grep -oP 'project\(substrate-wallpaper VERSION \K[0-9.]+' "$ROOT/CMakeLists.txt")"
NAME="Substrate-KDE-Wallpaper-$VERSION"
OUT="$ROOT/dist/$NAME.zip"

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

# Only what a build and an installation need
mkdir -p "$STAGE/$NAME"
cd "$ROOT"
cp -r CMakeLists.txt metadata.json install.sh uninstall.sh LICENSE README.md src contents "$STAGE/$NAME/"
# contents/ui/lib holds the plugin of the last build on this machine, it is built again by install.sh
rm -rf "$STAGE/$NAME/contents/ui/lib"

mkdir -p "$ROOT/dist"
rm -f "$OUT"
(cd "$STAGE" && python3 - "$NAME" "$OUT" <<'PY'
import os, sys, zipfile

name, out = sys.argv[1:3]
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    for folder, _, files in sorted(os.walk(name)):
        for f in sorted(files):
            path = os.path.join(folder, f)
            info = zipfile.ZipInfo.from_file(path)
            info.compress_type = zipfile.ZIP_DEFLATED
            z.writestr(info, open(path, "rb").read())  # keeps the executable bit of the scripts
PY
)
echo "Created $OUT ($(du -h "$OUT" | cut -f1))"
