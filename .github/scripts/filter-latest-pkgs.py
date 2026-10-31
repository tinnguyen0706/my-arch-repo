#!/usr/bin/env python3
import subprocess
import functools
from pathlib import Path
from collections import defaultdict

def cmp_versions(a, b):
    out = subprocess.run(['vercmp', a, b], capture_output=True, text=True).stdout.strip()
    return int(out) if out else 0

groups = defaultdict(list)
for p in Path('.').glob('*.pkg.tar.zst'):
    stem = p.name[:-len('.pkg.tar.zst')]
    parts = stem.rsplit('-', 3)
    if len(parts) == 4:
        pkgname, pkgver, pkgrel, arch = parts
        groups[(pkgname, arch)].append((f"{pkgver}-{pkgrel}", p.name))

latest_v3 = []
latest_v4 = []
for (pkgname, arch), items in groups.items():
    items.sort(key=functools.cmp_to_key(lambda x, y: cmp_versions(x[0], y[0])), reverse=True)
    top_pkg = items[0][1]
    if arch in ('x86_64', 'x86_64_v3', 'any'):
        latest_v3.append(top_pkg)
    if arch in ('x86_64', 'x86_64_v4', 'any'):
        latest_v4.append(top_pkg)

Path('pkgs_v3.txt').write_text('\n'.join(sorted(latest_v3)))
Path('pkgs_v4.txt').write_text('\n'.join(sorted(latest_v4)))
