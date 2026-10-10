#!/bin/sh
set -eu
ISO=${1:?usage: copy-iso-to-windows.sh path/to/iso}
WINHOME=$(wslpath "$(cmd.exe /c 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r')")
DEST="$WINHOME/RoseOS/iso"
mkdir -p "$DEST"
cp "$ISO" "$DEST/"
echo "$DEST/$(basename "$ISO")"
