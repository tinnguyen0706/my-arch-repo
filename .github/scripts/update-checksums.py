#!/usr/bin/env python3
import hashlib
import os
import re
import subprocess
import sys
import urllib.request

def calculate_sha256(filepath):
    h = hashlib.sha256()
    with open(filepath, "rb") as f:
        while chunk := f.read(65536):
            h.update(chunk)
    return h.hexdigest()

def update_pkgbuild_checksums(pkg_dir):
    pkgbuild_path = os.path.join(pkg_dir, "PKGBUILD")
    if not os.path.isfile(pkgbuild_path):
        return

    # Extract evaluated source and sha256sums arrays using bash
    bash_script = f"""
    cd "{pkg_dir}"
    source PKGBUILD 2>/dev/null || exit 1
    for s in "${{source[@]}}"; do
        printf "SOURCE:%s\\n" "$s"
    done
    for sum in "${{sha256sums[@]}}"; do
        printf "SUM:%s\\n" "$sum"
    done
    """
    res = subprocess.run(["bash", "-c", bash_script], capture_output=True, text=True)
    if res.returncode != 0:
        print(f"Error sourcing PKGBUILD in {pkg_dir}: {res.stderr}", file=sys.stderr)
        return

    sources = []
    old_sums = []
    for line in res.stdout.splitlines():
        if line.startswith("SOURCE:"):
            sources.append(line[len("SOURCE:"):])
        elif line.startswith("SUM:"):
            old_sums.append(line[len("SUM:"):])

    if not old_sums:
        return

    new_sums = []
    for idx, src in enumerate(sources):
        old_val = old_sums[idx] if idx < len(old_sums) else "SKIP"
        if old_val == "SKIP":
            new_sums.append("SKIP")
            continue

        # If source has custom filename syntax like "dest::http://..."
        url = src.split("::")[-1] if "::" in src else src

        if url.startswith("http://") or url.startswith("https://") or url.startswith("ftp://"):
            dest_filename = src.split("::")[0] if "::" in src else os.path.basename(url.split("?")[0])
            dest_path = os.path.join(pkg_dir, f".tmp_{dest_filename}")
            try:
                print(f"Downloading source to compute sha256: {url} -> {dest_path}")
                req = urllib.request.Request(url, headers={"User-Agent": "curl/8.0"})
                with urllib.request.urlopen(req) as resp, open(dest_path, "wb") as out_file:
                    while chunk := resp.read(65536):
                        out_file.write(chunk)
                computed = calculate_sha256(dest_path)
                new_sums.append(computed)
            except Exception as e:
                print(f"Failed to fetch {url}: {e}", file=sys.stderr)
                new_sums.append(old_val)
            finally:
                if os.path.exists(dest_path):
                    os.remove(dest_path)
        else:
            # Local file referenced in PKGBUILD source
            local_file = os.path.join(pkg_dir, url)
            if os.path.isfile(local_file):
                computed = calculate_sha256(local_file)
                new_sums.append(computed)
            else:
                new_sums.append(old_val)

    with open(pkgbuild_path, "r", encoding="utf-8") as f:
        content = f.read()

    formatted_sums = "sha256sums=(\n" + "\n".join(f"  '{s}'" for s in new_sums) + "\n)"
    new_content, count = re.subn(r"^sha256sums=\([^\)]*\)", formatted_sums, content, flags=re.MULTILINE | re.DOTALL)
    if count > 0:
        with open(pkgbuild_path, "w", encoding="utf-8") as f:
            f.write(new_content)
        print(f"Updated sha256sums for {pkg_dir}")

if __name__ == "__main__":
    if len(sys.argv) > 1:
        for p in sys.argv[1:]:
            update_pkgbuild_checksums(p)
