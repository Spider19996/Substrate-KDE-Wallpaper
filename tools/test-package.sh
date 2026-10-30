#!/usr/bin/env bash
# Tries a finished package (dist/Substrate-<version>-linux-<arch>.zip by default) on other distributions in
# podman containers: does its plugin load against their Qt? Needs podman and network access.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ZIP="$(readlink -f "${1:-$(ls "$ROOT"/dist/Substrate-*-linux-*.zip | head -1)}")"
IMAGES=(docker.io/library/debian:trixie docker.io/library/debian:testing docker.io/library/fedora:latest docker.io/library/archlinux:latest)

failed=0
for image in "${IMAGES[@]}"; do
    if ! podman run --rm -v "$ROOT/tests/package-smoke:/test:ro" -v "$ZIP:/package.zip:ro" "$image" \
            bash /test/run.sh /package.zip 2>&1 | grep -E "^(==|PASS|FAIL|Totals|qmltestrunner|.*not found|.*rror)"; then
        failed=1
    fi
    [[ ${PIPESTATUS[0]} -eq 0 ]] || failed=1
done
exit $failed
