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

# 2. Đồng bộ các file database hiện có từ VPS về runner (chỉ ~100 KB thay vì kéo toàn bộ kho package 1.8GB)
echo "Syncing existing database files from VPS via rsync..."
rsync -avL -e "$SSH_CMD" "${VPS_USER}@${VPS_HOST}:/var/www/repo/tinhiem*" ./ || true

# Chuẩn hóa và đồng bộ db/files archive để tránh crash CachyOS repo-add và dọn dẹp packages đã gỡ
python3 "$GITHUB_WORKSPACE/.github/scripts/sync-databases.py" "$GITHUB_WORKSPACE/packages.txt"
for f in *.pkg.tar.zst; do
  if [[ ! -s "$f" ]]; then
    echo "Removing empty/invalid package file $f"
    rm -f "$f"
  fi
done

pkgs_all=( *.pkg.tar.zst )
if (( ${#pkgs_all[@]} == 0 )); then
  echo "No new packages found to add to database."
else
  # 3. Phân loại và nạp các gói mới vừa build vào database repo-add (lũy kế)
  python3 "$GITHUB_WORKSPACE/.github/scripts/filter-latest-pkgs.py"

  mapfile -t pkgs_v3 < pkgs_v3.txt
  mapfile -t pkgs_v4 < pkgs_v4.txt

  if (( ${#pkgs_v3[@]} > 0 )); then
    echo "Updating tinhiem (v3) database: ${#pkgs_v3[@]} package(s)"
    repo-add "tinhiem.db.tar.gz" "${pkgs_v3[@]}"
  fi

  if (( ${#pkgs_v4[@]} > 0 )); then
    echo "Updating tinhiem-v4 database: ${#pkgs_v4[@]} package(s)"
    repo-add "tinhiem-v4.db.tar.gz" "${pkgs_v4[@]}"
  fi
  rm -f pkgs_v3.txt pkgs_v4.txt *.old

  echo "Deploying packages and databases to VPS /var/www/repo..."
  $SSH_CMD "${VPS_USER}@${VPS_HOST}" 'rm -f /var/www/repo/tinhiem*.db /var/www/repo/tinhiem*.files'
  rsync -avl -e "$SSH_CMD" *.pkg.tar.zst tinhiem*.db* tinhiem*.files* "${VPS_USER}@${VPS_HOST}:/var/www/repo/"
  $SSH_CMD "${VPS_USER}@${VPS_HOST}" 'cd /var/www/repo && ln -sf tinhiem.db.tar.gz tinhiem.db && ln -sf tinhiem.files.tar.gz tinhiem.files && ln -sf tinhiem-v4.db.tar.gz tinhiem-v4.db && ln -sf tinhiem-v4.files.tar.gz tinhiem-v4.files'

  # 4. Dọn dẹp bản cũ trên VPS: giữ tối đa 3 phiên bản gần nhất và xóa packages không còn trong packages.txt
  ACTIVE_LIST=$(grep -v '^#' "$GITHUB_WORKSPACE/packages.txt" | sed 's/local://' | sed '/^$/d' | tr '\n' ' ')
  $SSH_CMD "${VPS_USER}@${VPS_HOST}" "python3 - '$ACTIVE_LIST' << 'PYEOF'
import sys
from pathlib import Path
from collections import defaultdict

active_pkgs = set(sys.argv[1].split()) if len(sys.argv) > 1 and sys.argv[1].strip() else set()
repo_dir = Path('/var/www/repo')
groups = defaultdict(list)
for p in repo_dir.glob('*.pkg.tar.zst'):
    stem = p.name[:-len('.pkg.tar.zst')]
    parts = stem.rsplit('-', 3)
    if len(parts) == 4:
        pkgname, pkgver, pkgrel, arch = parts
        if active_pkgs and pkgname not in active_pkgs:
            p.unlink(missing_ok=True)
            continue
        groups[(pkgname, arch)].append(p)
for (pkgname, arch), files in groups.items():
    files.sort(key=lambda x: x.stat().st_mtime, reverse=True)
    for old_file in files[3:]:
        old_file.unlink(missing_ok=True)
PYEOF"
fi
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
  if [[ -f "$f" ]]; then
    pkg_status="$(cat "$f")"
    target_key="${f#status-failed-}"
    target_key="${target_key#status-restored-}"
    reason_file="reason-failed-${target_key}"
    if [[ -f "$reason_file" ]]; then
      reason_content="$(cat "$reason_file")"
      clean_title="${pkg_status%% —*}"
      FAILED_COMBINED_LOG+="- ${pkg_status}"$'\n\n'
      FAILED_COMBINED_LOG+="<details>"$'\n'
      FAILED_COMBINED_LOG+="<summary>🔍 Chi tiết lỗi: ${clean_title}</summary>"$'\n\n'
      FAILED_COMBINED_LOG+='```text'$'\n'
      FAILED_COMBINED_LOG+="${reason_content}"$'\n'
      FAILED_COMBINED_LOG+='```'$'\n\n'
      FAILED_COMBINED_LOG+="</details>"$'\n\n'
    else
      FAILED_COMBINED_LOG+="- ${pkg_status}"$'\n\n'
    fi
  fi
done
FAILED_COMBINED_LOG="${FAILED_COMBINED_LOG%$'\n\n'}"

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
