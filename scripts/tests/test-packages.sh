#!/bin/sh
set -eu
. "$(dirname "$0")/../lib/common.sh"

ROOT=${ROSEOS_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}
OUT="$ROOT/out/debs"

cr=$(printf '\r')
if grep -rlI "$cr" "$ROOT/packages" "$ROOT/scripts" "$ROOT/build/auto" "$ROOT/build/config" 2>/dev/null; then
    fail "files above contain Windows (CRLF) line endings"
fi

for pkg in roseos-archive-keyring roseos-desktop; do
    ls "$OUT/${pkg}"_*_all.deb >/dev/null 2>&1 || fail "missing package: $pkg"
done

lintian --fail-on error "$OUT"/*.deb || fail "lintian reported errors"

keyring_deb=$(ls "$OUT"/roseos-archive-keyring_*_all.deb)
contents=$(dpkg-deb -c "$keyring_deb")
echo "$contents" | grep -q ' ./usr/share/keyrings/roseos-archive-keyring.asc$' || fail "keyring file missing from $keyring_deb"
echo "$contents" | grep -q ' ./etc/apt/sources.list.d/roseos.sources$' || fail "APT source missing from $keyring_deb"
dpkg-deb -I "$keyring_deb" conffiles | grep -qx '/etc/apt/sources.list.d/roseos.sources' || fail "roseos.sources is not a conffile"

desktop_deb=$(ls "$OUT"/roseos-desktop_*_all.deb)
dpkg-deb -f "$desktop_deb" Depends | grep -q 'roseos-archive-keyring' || fail "roseos-desktop must depend on roseos-archive-keyring"

echo "PASS: packages"
