#!/usr/bin/env bash
# Builds Substrate and packs the finished Plasma wallpaper package (with its plugin inside) into
# dist/Substrate-<version>-linux-<arch>.zip. The archive has metadata.json and contents/ at its top level,
# so it can be installed with `kpackagetool6 -t Plasma/Wallpaper -i <zip>` or unzipped into
# ~/.local/share/plasma/wallpapers/com.github.spider19996.substrate/.
#
# The plugin is compiled code: it runs with the Qt version it was built against or a newer one (same major
# version, same CPU architecture). Build on the oldest Qt you want to support; the GitHub release workflow
# builds against Qt 6.5.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="$(grep -oP 'project\(substrate-wallpaper VERSION \K[0-9.]+' "$ROOT/CMakeLists.txt")"
ARCH="$(uname -m)"
OUT="$ROOT/dist/Substrate-$VERSION-linux-$ARCH.zip"
BUILD="$ROOT/build-package"

# No RPATH: the plugin finds the Qt libraries of the system it is installed on, not the ones it was built with
cmake -S "$ROOT" -B "$BUILD" -DCMAKE_BUILD_TYPE=Release -DCMAKE_SKIP_RPATH=ON
cmake --build "$BUILD" -j"$(nproc)"

[[ -f "$ROOT/contents/ui/lib/libsubstrate.so" ]] || { echo "The plugin was not built"; exit 1; }

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
command -v msgfmt >/dev/null || { echo "msgfmt (gettext) is needed to include the translations"; exit 1; }
"$ROOT/tools/build-translations.sh"
cp -r "$ROOT/metadata.json" "$ROOT/LICENSE" "$ROOT/contents" "$STAGE/"

mkdir -p "$ROOT/dist"
rm -f "$OUT"
(cd "$STAGE" && python3 - "$OUT" <<'PY'
import os, sys, zipfile

out = sys.argv[1]
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    for entry in ["metadata.json", "LICENSE"] + [os.path.join(d, f) for d, _, fs in sorted(os.walk("contents")) for f in sorted(fs)]:
        info = zipfile.ZipInfo.from_file(entry)
        info.compress_type = zipfile.ZIP_DEFLATED
        z.writestr(info, open(entry, "rb").read())
PY
)
echo "Created $OUT ($(du -h "$OUT" | cut -f1))"
echo "Built against Qt $(qmake6 -query QT_VERSION 2>/dev/null || echo '?'): it needs this Qt version or a newer one"
