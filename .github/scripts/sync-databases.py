#!/usr/bin/env python3
"""
sync-databases.py
Synchronizes and repairs pacman repository databases (db.tar.gz and files.tar.gz).

Guarantees:
1. Recovers db.tar.gz if standalone .db archive contains more packages (e.g. after prior desync).
2. Guarantees that every package entry present in db.tar.gz ALSO has a matching entry
   in files.tar.gz (collecting file lists across all available files archives). This prevents
   CachyOS pacman's Rust repo-add from panicking at fs::remove_dir_all(filesentry).unwrap()
   when updating existing packages.
3. Purges packages removed from packages.txt (e.g. auto-cpufreq, howdy-next).
4. Cleans up uncompressed .db and .files files so repo-add can recreate clean symlinks.
"""

import io
import os
import shutil
import sys
import tarfile
from pathlib import Path


def parse_active_pkgs(packages_txt_path):
    if not packages_txt_path or not os.path.exists(packages_txt_path):
        return None
    active = set()
    with open(packages_txt_path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            active.add(line.replace("local:", "").strip())
    return active


def get_pkg_name(entry_name):
    # Package entry in DB is <pkgname>-<pkgver>-<pkgrel>
    # e.g. "fmess-0.1.34-1" -> "fmess"
    # "umbriel-git-1:0.1.0.r1481.eb449f4-1" -> "umbriel-git"
    parts = entry_name.rsplit("-", 2)
    return parts[0] if len(parts) >= 3 else entry_name


def get_tar_packages(archive_path):
    if not os.path.exists(archive_path) or os.path.getsize(archive_path) == 0:
        return set()
    try:
        with tarfile.open(archive_path, "r:gz") as tar:
            return set(m.name.split("/")[0] for m in tar.getmembers() if "/" in m.name)
    except Exception as e:
        print(f"[sync-databases] Warning: failed to read {archive_path}: {e}")
        return set()


def collect_file_entries(search_dir="."):
    """Collect all package /files content across all available file archives."""
    all_files_entries = {}
    for entry in os.listdir(search_dir):
        if "files" in entry and (entry.endswith(".files") or entry.endswith(".files.tar.gz")):
            full_path = os.path.join(search_dir, entry)
            if not os.path.exists(full_path) or os.path.getsize(full_path) == 0:
                continue
            try:
                with tarfile.open(full_path, "r:gz") as tar:
                    for m in tar.getmembers():
                        if m.name.endswith("/files") and m.isfile():
                            pkg = m.name.split("/")[0]
                            if pkg not in all_files_entries:
                                all_files_entries[pkg] = tar.extractfile(m).read()
            except Exception as e:
                print(f"[sync-databases] Note: reading {entry}: {e}")
    return all_files_entries


def main():
    packages_txt = sys.argv[1] if len(sys.argv) > 1 else None
    active_pkgs = parse_active_pkgs(packages_txt)
    if active_pkgs is not None:
        print(f"[sync-databases] Found {len(active_pkgs)} active packages in {packages_txt}")

    repos = ["tinhiem", "tinhiem-v4"]

    # 1. Recover db.tar.gz from .db if .db has more entries
    for repo in repos:
        db_file = f"{repo}.db"
        db_tar = f"{repo}.db.tar.gz"

        pkgs_db = get_tar_packages(db_file)
        pkgs_tar = get_tar_packages(db_tar)
        print(f"[sync-databases] [{repo}] {db_file}: {len(pkgs_db)} pkgs, {db_tar}: {len(pkgs_tar)} pkgs")

        if len(pkgs_db) > len(pkgs_tar):
            print(f"[sync-databases] [{repo}] Recovering {db_tar} from {db_file} ({len(pkgs_db)} > {len(pkgs_tar)})")
            shutil.copyfile(db_file, db_tar)

    # 2. Collect all /files entries
    all_files = collect_file_entries(".")
    print(f"[sync-databases] Collected /files entries for {len(all_files)} packages across file databases.")

    # 3. Synchronize db.tar.gz and files.tar.gz for each repository
    for repo in repos:
        db_tar = f"{repo}.db.tar.gz"
        files_tar = f"{repo}.files.tar.gz"

        if not os.path.exists(db_tar):
            continue

        with tarfile.open(db_tar, "r:gz") as tar_db:
            db_members = tar_db.getmembers()
            pkgs_in_db = sorted(list(set(m.name.split("/")[0] for m in db_members if "/" in m.name)))

            # Filter active packages if active_pkgs list is known
            if active_pkgs is not None:
                kept_pkgs = [p for p in pkgs_in_db if get_pkg_name(p) in active_pkgs]
                purged_pkgs = [p for p in pkgs_in_db if get_pkg_name(p) not in active_pkgs]
                if purged_pkgs:
                    print(f"[sync-databases] [{repo}] Purging inactive packages: {purged_pkgs}")
            else:
                kept_pkgs = pkgs_in_db

            # Rewrite clean db.tar.gz
            temp_db_tar = f"{db_tar}.tmp"
            with tarfile.open(temp_db_tar, "w:gz") as out_db:
                for pkg in kept_pkgs:
                    desc_member = tar_db.getmember(f"{pkg}/desc")
                    desc_content = tar_db.extractfile(desc_member).read()
                    ti_desc = tarfile.TarInfo(name=f"{pkg}/desc")
                    ti_desc.size = len(desc_content)
                    out_db.addfile(ti_desc, io.BytesIO(desc_content))
            os.replace(temp_db_tar, db_tar)

            # Rewrite matching files.tar.gz with identical package set
            temp_files_tar = f"{files_tar}.tmp"
            with tarfile.open(temp_files_tar, "w:gz") as out_files:
                for pkg in kept_pkgs:
                    # 1. Add desc matching db.tar.gz
                    desc_member = tar_db.getmember(f"{pkg}/desc")
                    desc_content = tar_db.extractfile(desc_member).read()
                    ti_desc = tarfile.TarInfo(name=f"{pkg}/desc")
                    ti_desc.size = len(desc_content)
                    out_files.addfile(ti_desc, io.BytesIO(desc_content))

                    # 2. Add files entry
                    files_content = all_files.get(pkg, b"")
                    ti_files = tarfile.TarInfo(name=f"{pkg}/files")
                    ti_files.size = len(files_content)
                    out_files.addfile(ti_files, io.BytesIO(files_content))

            os.replace(temp_files_tar, files_tar)
            print(f"[sync-databases] [{repo}] Successfully synchronized {db_tar} and {files_tar} ({len(kept_pkgs)} packages).")

    # 4. Remove uncompressed .db and .files files so repo-add can recreate symlinks
    for repo in repos:
        for ext in [".db", ".files"]:
            p = f"{repo}{ext}"
            if os.path.exists(p) and not os.path.islink(p):
                os.remove(p)
                print(f"[sync-databases] Removed uncompressed file {p} for symlink creation.")


if __name__ == "__main__":
    main()
