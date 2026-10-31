#!/usr/bin/env bash
set -euo pipefail

# Enable DisableSandboxNetwork for pacman in container
sed -i '/^\[options\]/a DisableSandboxNetwork' /etc/pacman.conf

if ! grep -q '\[chaotic-aur\]' /etc/pacman.conf; then
{
  echo ""
  echo "[chaotic-aur]"
  echo "SigLevel = Optional TrustAll"
  echo "Server = https://geo-mirror.chaotic.cx/chaotic-aur/x86_64"
  echo "Server = https://builds.garudalinux.org/repos/chaotic-aur/x86_64"
  echo "Server = https://cdn-mirror.chaotic.cx/chaotic-aur/x86_64"
} >> /etc/pacman.conf
fi

pacman -Syu --noconfirm --needed \
  git subversion mercurial sudo rsync github-cli fakeroot binutils \
  pacman-contrib paru curl awk tar jq rustup cmake clang perl \
  python-build python-installer python-wheel python-setuptools lito

id builder >/dev/null 2>&1 || useradd -m builder
grep -q '^builder ALL=(ALL) NOPASSWD: ALL$' /etc/sudoers || echo "builder ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

rustup default stable
sudo -u builder rustup default stable
