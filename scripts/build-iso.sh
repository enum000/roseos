#!/bin/sh
set -eu
. "$(dirname "$0")/lib/common.sh"

ROOT=${ROSEOS_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}
MIN_FREE_GB=${ROSEOS_MIN_FREE_GB:-25}

case "$ROOT" in
    /mnt/*)
        echo "ERROR: $ROOT is on a Windows drive. Clone the project inside WSL (e.g. ~/roseos) and build there." >&2
        exit 2
        ;;
esac

check_free() {
    free_gb=$(df -BG --output=avail "$1" | tail -1 | tr -dc '0-9')
    if [ "$free_gb" -lt "$MIN_FREE_GB" ]; then
        echo "ERROR: need at least ${MIN_FREE_GB}G free on $1, have ${free_gb}G." >&2
        exit 3
    fi
}
check_free "$ROOT"
# WSL's virtual disk reports its maximum size; the real limit is the Windows drive holding it.
if grep -qi microsoft /proc/version 2>/dev/null && [ -d /mnt/c ]; then
    check_free /mnt/c
fi

cd "$ROOT/build"
as_root lb clean
as_root lb config
as_root lb build

iso=$(ls -t ./*.iso 2>/dev/null | head -1)
[ -n "$iso" ] || fail "live-build did not produce an ISO; see build/build.log"
mkdir -p "$ROOT/out"
as_root mv "$iso" "$ROOT/out/roseos-1.0-amd64.iso"
as_root chown "$(id -u):$(id -g)" "$ROOT/out/roseos-1.0-amd64.iso"
echo "$ROOT/out/roseos-1.0-amd64.iso"
