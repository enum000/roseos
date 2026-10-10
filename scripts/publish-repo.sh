#!/bin/sh
set -eu
. "$(dirname "$0")/lib/common.sh"

DEBS=${1:?usage: publish-repo.sh <debs-dir> <repo-dir>}
REPO=${2:?usage: publish-repo.sh <debs-dir> <repo-dir>}
: "${ROSEOS_GPG_KEY:?set ROSEOS_GPG_KEY to the signing key fingerprint}"
: "${ROSEOS_GPG_PASSPHRASE_FILE:?set ROSEOS_GPG_PASSPHRASE_FILE}"
: "${ROSEOS_VERIFY_KEYRING:?set ROSEOS_VERIFY_KEYRING to the .asc keyring users have}"

mkdir -p "$REPO"
DEBS=$(realpath "$DEBS")
REPO=$(realpath "$REPO")
ROSEOS_GPG_PASSPHRASE_FILE=$(realpath "$ROSEOS_GPG_PASSPHRASE_FILE")
ROSEOS_VERIFY_KEYRING=$(realpath "$ROSEOS_VERIFY_KEYRING")

SUITE=trixie
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT

ls "$DEBS"/*.deb >/dev/null 2>&1 || fail "no .deb files in $DEBS"
mkdir -p "$STAGE/pool/main" "$STAGE/dists/$SUITE/main/binary-amd64"
cp "$DEBS"/*.deb "$STAGE/pool/main/"

cd "$STAGE"
apt-ftparchive packages pool/main > "dists/$SUITE/main/binary-amd64/Packages"
gzip -9kn "dists/$SUITE/main/binary-amd64/Packages"
apt-ftparchive \
    -o APT::FTPArchive::Release::Origin="Rose OS" \
    -o APT::FTPArchive::Release::Label="Rose OS" \
    -o APT::FTPArchive::Release::Suite="$SUITE" \
    -o APT::FTPArchive::Release::Codename="$SUITE" \
    -o APT::FTPArchive::Release::Architectures="amd64" \
    -o APT::FTPArchive::Release::Components="main" \
    -o APT::FTPArchive::Release::Description="Rose OS packages" \
    release "dists/$SUITE" > "$STAGE/Release.tmp"
mv "$STAGE/Release.tmp" "dists/$SUITE/Release"

sign() {
    gpg --batch --yes --pinentry-mode loopback \
        --passphrase-file "$ROSEOS_GPG_PASSPHRASE_FILE" \
        --local-user "$ROSEOS_GPG_KEY" --digest-algo SHA512 "$@"
}
sign --clearsign -o "dists/$SUITE/InRelease" "dists/$SUITE/Release"
sign --armor --detach-sign -o "dists/$SUITE/Release.gpg" "dists/$SUITE/Release"

gpg --dearmor < "$ROSEOS_VERIFY_KEYRING" > "$STAGE/verify.gpg"
gpgv --keyring "$STAGE/verify.gpg" "dists/$SUITE/InRelease" 2>/dev/null \
    || fail "InRelease is not signed by the key in $ROSEOS_VERIFY_KEYRING"
gpgv --keyring "$STAGE/verify.gpg" "dists/$SUITE/Release.gpg" "dists/$SUITE/Release" 2>/dev/null \
    || fail "Release.gpg is not signed by the key in $ROSEOS_VERIFY_KEYRING"
rm -f "$STAGE/verify.gpg"

cp "$ROSEOS_VERIFY_KEYRING" roseos-archive-keyring.asc
touch .nojekyll

rm -rf "$REPO/pool" "$REPO/dists"
mv pool dists "$REPO/"
cp roseos-archive-keyring.asc .nojekyll "$REPO/"
echo "Published $(ls "$REPO/pool/main" | wc -l) packages to $REPO"
