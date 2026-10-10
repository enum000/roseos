#!/bin/sh
set -eu
. "$(dirname "$0")/../lib/common.sh"

ISO=${1:?usage: test-iso.sh path/to/roseos.iso}
EXPECTED="$(dirname "$0")/iso-expected-paths.txt"
MAX_BYTES=4500000000

[ -f "$ISO" ] || fail "ISO not found: $ISO"
size=$(stat -c %s "$ISO")
[ "$size" -lt "$MAX_BYTES" ] || fail "ISO is too large: $size bytes"

MNT=$(mktemp -d)
LIST=$(mktemp)
cleanup() {
    as_root umount "$MNT" 2>/dev/null || true
    rmdir "$MNT" 2>/dev/null || true
    rm -f "$LIST"
}
trap cleanup EXIT

as_root mount -o loop,ro "$ISO" "$MNT"
unsquashfs -l "$MNT/live/filesystem.squashfs" | sed -n 's#^squashfs-root##p' > "$LIST"

while IFS= read -r line; do
    case "$line" in ''|'#'*) continue ;; esac
    kind=${line%%:*}
    path=${line#*:}
    case "$kind" in
        iso) [ -n "$(find "$MNT" -ipath "$MNT/$path" -print -quit)" ] || fail "missing in ISO: $path" ;;
        fs) grep -qxF "$path" "$LIST" || fail "missing in live filesystem: $path" ;;
        *) fail "bad line in $EXPECTED: $line" ;;
    esac
done < "$EXPECTED"

echo "PASS: $ISO ($size bytes)"
