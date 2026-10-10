#!/bin/sh
set -eu
. "$(dirname "$0")/lib/common.sh"

ROOT=${ROSEOS_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}
OUT="$ROOT/out/debs"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

rm -rf "$OUT"
mkdir -p "$OUT"

for dir in "$ROOT"/packages/*/; do
    name=$(basename "$dir")
    cp -a "$dir" "$WORK/$name"
    (cd "$WORK/$name" && dpkg-buildpackage -b --no-sign) || fail "build failed: $name"
done

mv "$WORK"/*.deb "$OUT"/
ls -1 "$OUT"
