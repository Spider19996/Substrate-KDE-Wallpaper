#!/usr/bin/env bash
# Smoke test for the finished wallpaper package: unpacks it and checks that its plugin loads against the Qt of the
# system this runs on. Installs the little it needs itself (Debian/Ubuntu, Fedora or Arch); meant for containers.
#
#   tests/package-smoke/run.sh dist/Substrate-1.0.0-linux-x86_64.zip
set -uo pipefail

ZIP="$(readlink -f "${1:?usage: run.sh <package zip>}")"
HERE="$(cd "$(dirname "$0")" && pwd)"
. /etc/os-release

case "$ID" in
  debian|ubuntu)
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get install -y -qq --no-install-recommends unzip qt6-declarative-dev-tools qml6-module-qtquick qml6-module-qttest >/dev/null ;;
  fedora) dnf install -y -q unzip qt6-qtdeclarative-devel >/dev/null ;;
  arch)   pacman -Sy --noconfirm --needed unzip qt6-declarative >/dev/null 2>&1 ;;
  *) echo "Unsupported system: $ID"; exit 2 ;;
esac

RUNNER="$(command -v qmltestrunner6 || command -v qmltestrunner || find /usr -name qmltestrunner -type f 2>/dev/null | head -1)"
QT_VERSION="$(find /usr -name 'libQt6Core.so.6.*' 2>/dev/null | head -1 | sed 's/.*so\.//')"
[[ -n "$RUNNER" ]] || { echo "qmltestrunner not found"; exit 2; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
unzip -q "$ZIP" -d "$WORK"
cp "$HERE/tst_smoke.qml" "$WORK/contents/ui/"

echo "== $PRETTY_NAME, Qt $QT_VERSION"
cd "$WORK/contents/ui"
QT_QPA_PLATFORM=offscreen timeout 120 "$RUNNER" -input tst_smoke.qml
