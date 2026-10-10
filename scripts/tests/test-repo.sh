#!/bin/sh
set -eu
. "$(dirname "$0")/../lib/common.sh"

ROOT=${ROSEOS_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}
PUBLISH="$ROOT/scripts/publish-repo.sh"
DEBS="$ROOT/out/debs"
WORK=$(mktemp -d)
trap 'as_root rm -rf "$WORK"' EXIT

ls "$DEBS"/*.deb >/dev/null 2>&1 || fail "no packages in $DEBS; run scripts/build-packages.sh first"

export GNUPGHOME="$WORK/gnupg"
mkdir -m 700 "$GNUPGHOME"
printf 'test-passphrase' > "$WORK/pass"
printf 'wrong-passphrase' > "$WORK/badpass"
gen_key() {
    gpg --batch --quiet --pinentry-mode loopback --passphrase-file "$WORK/pass" \
        --quick-gen-key "$1" ed25519 sign 1d
    gpg --list-secret-keys --with-colons "$1" | awk -F: '/^fpr:/ {print $10; exit}'
}
FPR=$(gen_key "Rose OS Test Key")
OTHER_FPR=$(gen_key "Someone Else")
gpg --armor --export "$FPR" > "$WORK/test-key.asc"

# 1. Wrong passphrase: publish fails and leaves no dists/.
mkdir "$WORK/repo-bad"
if ROSEOS_GPG_KEY=$FPR ROSEOS_GPG_PASSPHRASE_FILE="$WORK/badpass" ROSEOS_VERIFY_KEYRING="$WORK/test-key.asc" \
    "$PUBLISH" "$DEBS" "$WORK/repo-bad" >/dev/null 2>&1; then
    fail "publish succeeded with a wrong passphrase"
fi
[ ! -e "$WORK/repo-bad/dists" ] || fail "publish left dists/ behind after failing"

# 2. Signing key differs from the shipped keyring: publish refuses.
mkdir "$WORK/repo-other"
if ROSEOS_GPG_KEY=$OTHER_FPR ROSEOS_GPG_PASSPHRASE_FILE="$WORK/pass" ROSEOS_VERIFY_KEYRING="$WORK/test-key.asc" \
    "$PUBLISH" "$DEBS" "$WORK/repo-other" >/dev/null 2>&1; then
    fail "publish succeeded although the signature does not match the shipped keyring"
fi
[ ! -e "$WORK/repo-other/dists" ] || fail "publish left dists/ behind after key mismatch"

# 3. Happy path.
mkdir "$WORK/repo"
echo "keep me" > "$WORK/repo/README.md"
ROSEOS_GPG_KEY=$FPR ROSEOS_GPG_PASSPHRASE_FILE="$WORK/pass" ROSEOS_VERIFY_KEYRING="$WORK/test-key.asc" \
    "$PUBLISH" "$DEBS" "$WORK/repo"
for f in dists/trixie/InRelease dists/trixie/Release.gpg dists/trixie/main/binary-amd64/Packages.gz .nojekyll roseos-archive-keyring.asc README.md; do
    [ -e "$WORK/repo/$f" ] || fail "repo is missing $f"
done

SOURCES='Types: deb\nURIs: file:/srv/repo\nSuites: trixie\nComponents: main\nSigned-By: /usr/share/keyrings/test-key.asc\n'

# 4. Install from the signed repo in a clean Debian 13 chroot.
as_root mmdebstrap --variant=apt --quiet \
    --setup-hook='mkdir -p "$1/srv/repo" "$1/usr/share/keyrings"' \
    --setup-hook="sync-in $WORK/repo /srv/repo" \
    --setup-hook="copy-in $WORK/test-key.asc /usr/share/keyrings" \
    --customize-hook="printf '$SOURCES' > \"\$1/etc/apt/sources.list.d/roseos-test.sources\"" \
    --customize-hook='chroot "$1" apt-get update' \
    --customize-hook='chroot "$1" apt-get install -y roseos-desktop' \
    --customize-hook='chroot "$1" test -f /usr/share/keyrings/roseos-archive-keyring.asc' \
    --customize-hook='chroot "$1" test -f /etc/apt/sources.list.d/roseos.sources' \
    trixie /dev/null || fail "installing roseos-desktop from the signed repo failed"

# 5. Tampered repo: apt must refuse it.
cp -a "$WORK/repo" "$WORK/repo-tampered"
sed -i 's/^Label: Rose OS$/Label: Evil/' "$WORK/repo-tampered/dists/trixie/InRelease"
as_root mmdebstrap --variant=apt --quiet \
    --setup-hook='mkdir -p "$1/srv/repo" "$1/usr/share/keyrings"' \
    --setup-hook="sync-in $WORK/repo-tampered /srv/repo" \
    --setup-hook="copy-in $WORK/test-key.asc /usr/share/keyrings" \
    --customize-hook="printf '$SOURCES' > \"\$1/etc/apt/sources.list.d/roseos-test.sources\"" \
    --customize-hook='chroot "$1" apt-get update || true' \
    --customize-hook='if chroot "$1" apt-get install -y roseos-desktop; then echo "tampered repo was accepted" >&2; exit 1; fi' \
    trixie /dev/null || fail "apt accepted a tampered repository"

echo "PASS: repo"
