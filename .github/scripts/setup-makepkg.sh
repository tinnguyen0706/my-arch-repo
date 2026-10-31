#!/usr/bin/env bash
set -euo pipefail

TARGET_ARCH="${1:-v3}"
TARGET_PROFILE="${2:-docker-makepkg-v3}"
TARGET_PKGCARCH="${3:-x86_64_v3}"

echo "Configuring makepkg for ${TARGET_ARCH} (${TARGET_PROFILE}, ${TARGET_PKGCARCH})..."

mkdir -p /etc/makepkg.conf.d /etc/profile.d

curl -sLo /etc/makepkg.conf "https://raw.githubusercontent.com/CachyOS/docker-makepkg/refs/heads/master/${TARGET_PROFILE}/makepkg.conf"
curl -sLo /etc/makepkg.conf.d/rust.conf "https://raw.githubusercontent.com/CachyOS/docker-makepkg/refs/heads/master/${TARGET_PROFILE}/rust.conf"

sed -i 's/^PKGDEST=/#PKGDEST=/g' /etc/makepkg.conf
sed -i 's/^LOGDEST=/#LOGDEST=/g' /etc/makepkg.conf
sed -i 's/^PACKAGECARCH=/#PACKAGECARCH=/g' /etc/makepkg.conf
echo "PACKAGECARCH=\"${TARGET_PKGCARCH}\"" >> /etc/makepkg.conf

echo 'export CARGO_HOST_RUSTFLAGS="-C target-cpu=x86-64-v3"' >> /etc/profile.d/cargo-host.sh
echo 'export CARGO_TARGET_APPLIES_TO_HOST=false' >> /etc/profile.d/cargo-host.sh
echo 'CARGO_HOST_RUSTFLAGS="-C target-cpu=x86-64-v3"' >> /etc/environment
echo 'CARGO_TARGET_APPLIES_TO_HOST=false' >> /etc/environment
