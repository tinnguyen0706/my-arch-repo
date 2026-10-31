#!/usr/bin/env bash
set -euo pipefail

SSH_KEY="${1:-}"
VPS_HOST="${2:-}"
VPS_USER="${3:-}"
REPO="${4:-}"
TAG="${5:-repository}"
SHA="${6:-}"

mkdir -p output
cd output
shopt -s nullglob

# 1. Cấu hình SSH để kết nối VPS
mkdir -p "$HOME/.ssh" /root/.ssh 2>/dev/null || true
chmod 700 "$HOME/.ssh" /root/.ssh 2>/dev/null || true
printf '%s\n' "$SSH_KEY" > "$HOME/.ssh/id_ed25519"
cp "$HOME/.ssh/id_ed25519" /root/.ssh/id_ed25519 2>/dev/null || true
chmod 600 "$HOME/.ssh/id_ed25519" /root/.ssh/id_ed25519 2>/dev/null || true
ssh-keyscan -H "$VPS_HOST" >> "$HOME/.ssh/known_hosts" 2>/dev/null || true

SSH_CMD="ssh -i $HOME/.ssh/id_ed25519 -o StrictHostKeyChecking=accept-new"

# 2. Đồng bộ toàn bộ các file gói đang có trên VPS về runner
echo "Syncing all existing packages from VPS via rsync..."
rsync -av --ignore-existing -e "$SSH_CMD" "${VPS_USER}@${VPS_HOST}:/var/www/repo/*.pkg.tar.zst" ./ || true

for f in *.pkg.tar.zst; do
  if [[ ! -s "$f" ]]; then
    echo "Removing empty/invalid package file $f"
    rm -f "$f"
  fi
done

pkgs_all=( *.pkg.tar.zst )
if (( ${#pkgs_all[@]} == 0 )); then
  echo "No packages found. Exiting."
  exit 0
fi

# 3. Lọc chỉ nạp phiên bản cao nhất của từng package vào database repo-add
python3 "$GITHUB_WORKSPACE/.github/scripts/filter-latest-pkgs.py"

mapfile -t pkgs_v3 < pkgs_v3.txt
mapfile -t pkgs_v4 < pkgs_v4.txt

if (( ${#pkgs_v3[@]} > 0 )); then
  echo "Creating tinhiem (v3) database: ${#pkgs_v3[@]} package(s)"
  repo-add "tinhiem.db.tar.gz" "${pkgs_v3[@]}"
fi

if (( ${#pkgs_v4[@]} > 0 )); then
  echo "Creating tinhiem-v4 database: ${#pkgs_v4[@]} package(s)"
  repo-add "tinhiem-v4.db.tar.gz" "${pkgs_v4[@]}"
fi
rm -f pkgs_v3.txt pkgs_v4.txt

echo "Deploying packages and databases to VPS /var/www/repo..."
rsync -av -e "$SSH_CMD" *.pkg.tar.zst tinhiem*.db* tinhiem*.files* "${VPS_USER}@${VPS_HOST}:/var/www/repo/"

# 4. Dọn dẹp bản cũ trên VPS: giữ tối đa 3 phiên bản gần nhất
$SSH_CMD "${VPS_USER}@${VPS_HOST}" 'python3 - << "PYEOF"
from pathlib import Path
from collections import defaultdict
repo_dir = Path("/var/www/repo")
groups = defaultdict(list)
for p in repo_dir.glob("*.pkg.tar.zst"):
    stem = p.name[:-len(".pkg.tar.zst")]
    parts = stem.rsplit("-", 3)
    if len(parts) == 4:
        pkgname, pkgver, pkgrel, arch = parts
        groups[(pkgname, arch)].append(p)
for (pkgname, arch), files in groups.items():
    files.sort(key=lambda x: x.stat().st_mtime, reverse=True)
    for old_file in files[3:]:
        old_file.unlink(missing_ok=True)
PYEOF'

# 5. Cập nhật Release Tag trên GitHub (Chỉ lưu Changelog & Notes)
if ! gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
  gh release create "$TAG" --repo "$REPO" \
    --title "Arch Package Repository" \
    --notes "Automated release tag."
fi

status_built=( status-built-*.txt )
status_skipped=( status-skipped-*.txt )
status_restored=( status-restored-*.txt )
status_failed=( status-failed-*.txt )

BUILT_LOG=""
for f in "${status_built[@]}"; do [[ -f "$f" ]] && BUILT_LOG+="- $(cat "$f")"$'\n'; done

SKIPPED_LOG=""
for f in "${status_skipped[@]}"; do [[ -f "$f" ]] && SKIPPED_LOG+="- $(cat "$f")"$'\n'; done

FAILED_COMBINED_LOG=""
for f in "${status_failed[@]}" "${status_restored[@]}"; do
  [[ -f "$f" ]] && FAILED_COMBINED_LOG+="- $(cat "$f")"$'\n'
done

RELEASE_NOTES=$(cat <<EOF
### 📦 Repository Update Summary
**Cập nhật lúc:** $(TZ='Asia/Ho_Chi_Minh' date '+%Y-%m-%d %H:%M (UTC+7)')

- 🔗 **Changelog / Commit Diff:** https://github.com/${REPO}/commit/${SHA}
- 🌐 **Máy chủ tải gói (VPS):** https://arch.tinhiem.id.vn/

#### ✅ Gói mới biên dịch thành công:
${BUILT_LOG:-None}

#### ⚡ Gói tận dụng cache (bỏ qua compile):
${SKIPPED_LOG:-None}

#### ❌ Gói build thất bại:
${FAILED_COMBINED_LOG:-None}
EOF
)
gh release edit "$TAG" --repo "$REPO" --title "Arch Repository Release" --notes "$RELEASE_NOTES"
