#!/usr/bin/env bash
set -uo pipefail

PKG="${1:-}"
DB_NAME="${2:-}"
TARGET_ARCH="${3:-}"

if [[ -z "$PKG" || -z "$DB_NAME" || -z "$TARGET_ARCH" ]]; then
  echo "Usage: $0 <package> <db_name> <target_arch>"
  exit 1
fi

mkdir -p output /tmp/repo-files /tmp/repo-db

echo "Fetching database metadata for $DB_NAME from VPS..."
if curl -sSLf "https://arch.tinhiem.id.vn/${DB_NAME}.files.tar.gz" -o "/tmp/repo-db/${DB_NAME}.files.tar.gz" 2>/dev/null; then
  if ! tar -xzf "/tmp/repo-db/${DB_NAME}.files.tar.gz" -C /tmp/repo-files; then
    echo "::warning::Cannot extract ${DB_NAME}.files.tar.gz; treating as rebuild."
  fi
else
  echo "::warning::No ${DB_NAME}.files.tar.gz on VPS; treating as rebuild."
fi

echo "Checking status for $PKG ($TARGET_ARCH)"
VCS_PREPASS_OK=true
if grep -q 'pkgver()' "$PKG/PKGBUILD"; then
  if ! sudo -u builder bash -lc "cd '$GITHUB_WORKSPACE/$PKG' && makepkg -od --noprepare --skipinteg"; then
    echo "::warning::pkgver() pre-pass failed for $PKG; forcing rebuild."
    VCS_PREPASS_OK=false
  fi
fi

EXPECTED_PKGS=""
if ! EXPECTED_PKGS=$(sudo -u builder bash -lc "cd '$GITHUB_WORKSPACE/$PKG' && makepkg --packagelist"); then
  echo "::warning::makepkg --packagelist failed for $PKG; forcing rebuild."
  EXPECTED_PKGS=""
fi
EXPECTED_PKGS="${EXPECTED_PKGS//:/.}"

NEEDS_BUILD=false
if [[ "$VCS_PREPASS_OK" != "true" || -z "$EXPECTED_PKGS" ]]; then
  NEEDS_BUILD=true
else
  for pkg_path in $EXPECTED_PKGS; do
    pkg_basename=$(basename "$pkg_path")
    if ! grep -q -x "$pkg_basename" /tmp/repo-files/*/desc 2>/dev/null; then
      NEEDS_BUILD=true
      break
    fi
  done
fi

if [[ "$NEEDS_BUILD" == "false" ]]; then
  echo "Package $PKG ($TARGET_ARCH) is up to date. Fetching specific cache from release."
  for pkg_path in $EXPECTED_PKGS; do
    pkg_basename=$(basename "$pkg_path")
    if ! curl -sSLf "https://arch.tinhiem.id.vn/$pkg_basename" -o "output/$pkg_basename" 2>/dev/null; then
      echo "::warning::Failed to fetch $pkg_basename cache. Forcing rebuild."
      NEEDS_BUILD=true
      break
    fi
  done
fi

if [[ "$NEEDS_BUILD" == "false" ]]; then
  echo "$PKG ($TARGET_ARCH)" > "output/status-skipped-${PKG}-${TARGET_ARCH}.txt"
else
  echo "Updating checksums for $PKG..."
  if [[ "$PKG" == "office-craft" ]]; then
    echo "Building meta-package $PKG with makepkg -d..."
    sudo -u builder bash -lc "cd '$GITHUB_WORKSPACE/$PKG' && makepkg -d --noconfirm"
  else
    ASSUME_PKGS=$(sudo -u builder bash -lc "cd '$GITHUB_WORKSPACE/$PKG' && source PKGBUILD && echo \${pkgname[@]}")
    ASSUME_ARGS=""
    for subpkg in $ASSUME_PKGS; do
      ASSUME_ARGS="$ASSUME_ARGS --assume-installed $subpkg"
    done
    PARU_FLAGS="--noconfirm --skipreview --useask --removemake --nocheck -B$ASSUME_ARGS"
    if ! sudo -u builder bash -lc "cd '$GITHUB_WORKSPACE/$PKG' && paru $PARU_FLAGS '$GITHUB_WORKSPACE/$PKG'"; then
      echo "::warning::paru exited non-zero for $PKG; checking produced packages."
    fi
  fi

  if ls "$PKG"/*.pkg.tar.zst >/dev/null 2>&1; then
    mv "$PKG"/*.pkg.tar.zst output/
    echo "Build OK: $PKG ($TARGET_ARCH)"
    echo "$PKG ($TARGET_ARCH)" > "output/status-built-${PKG}-${TARGET_ARCH}.txt"
  else
    echo "Build failed for $PKG ($TARGET_ARCH). Triggering fallback."
    FALLBACK_CANDIDATES=()
    declare -A candidate_seen=()
    add_candidate() {
      [[ -n "$1" ]] || return 0
      [[ -n "${candidate_seen[$1]:-}" ]] && return 0
      candidate_seen["$1"]=1
      FALLBACK_CANDIDATES+=("$1")
    }
    if [[ -d /tmp/repo-files ]]; then
      for desc_file in /tmp/repo-files/*/desc; do
        [[ -f "$desc_file" ]] || continue
        base_pkg=$(awk '/^%BASE%/{getline; print; exit}' "$desc_file")
        pkg_name=$(awk '/^%NAME%/{getline; print; exit}' "$desc_file")
        check_name="${base_pkg:-$pkg_name}"
        [[ "$check_name" == "$PKG" ]] || continue
        add_candidate "$(awk '/^%FILENAME%/{getline; print; exit}' "$desc_file")"
      done
    fi
    RESTORED_COUNT=0
    for file_name in "${FALLBACK_CANDIDATES[@]}"; do
      if curl -sSLf "https://arch.tinhiem.id.vn/$file_name" -o "output/$file_name" 2>/dev/null; then
        RESTORED_COUNT=$(( RESTORED_COUNT + 1 ))
      fi
    done
    if (( RESTORED_COUNT > 0 )); then
      echo "Restored previous build for $PKG ($TARGET_ARCH)"
      echo "$PKG ($TARGET_ARCH) — (fallback: $(basename "${FALLBACK_CANDIDATES[0]}"))" > "output/status-restored-${PKG}-${TARGET_ARCH}.txt"
    else
      echo "Fallback failed: no previous file for $PKG ($TARGET_ARCH)"
      echo "$PKG ($TARGET_ARCH)" > "output/status-failed-${PKG}-${TARGET_ARCH}.txt"
    fi
  fi
fi

for f in output/*:* ; do
  if [[ -f "$f" ]]; then
    new_f="${f//:/.}"
    echo "Renaming $f to $new_f"
    mv "$f" "$new_f"
  fi
done

sudo -u builder rm -rf "$GITHUB_WORKSPACE/$PKG/src" "$GITHUB_WORKSPACE/$PKG/pkg"
