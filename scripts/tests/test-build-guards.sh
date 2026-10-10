#!/bin/sh
set -u
. "$(dirname "$0")/../lib/common.sh"
SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/build-iso.sh"

ROSEOS_ROOT=/mnt/c/fake-roseos "$SCRIPT" >/dev/null 2>&1
rc=$?
[ "$rc" -eq 2 ] || fail "expected exit 2 when project is under /mnt, got $rc"

ROSEOS_MIN_FREE_GB=999999 "$SCRIPT" >/dev/null 2>&1
rc=$?
[ "$rc" -eq 3 ] || fail "expected exit 3 when disk space is low, got $rc"

# In WSL the virtual disk reports its maximum size; the real limit is the Windows drive.
if grep -qi microsoft /proc/version 2>/dev/null && [ -d /mnt/c ]; then
    host_free=$(df -BG --output=avail /mnt/c | tail -1 | tr -dc '0-9')
    ROSEOS_MIN_FREE_GB=$((host_free + 1)) "$SCRIPT" >/dev/null 2>&1
    rc=$?
    [ "$rc" -eq 3 ] || fail "expected exit 3 when the Windows drive behind WSL is low on space, got $rc"
fi

echo "PASS: build guards"
