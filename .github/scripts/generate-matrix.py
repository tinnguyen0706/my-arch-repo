#!/usr/bin/env python3
import json
import sys
from pathlib import Path

pkgs = sys.argv[1:]
matrix = []
for pkg in pkgs:
    p = Path(pkg) / 'PKGBUILD'
    content = p.read_text() if p.exists() else ''
    is_any = any(line.strip().startswith(("arch=('any')", 'arch=(any)')) for line in content.splitlines())
    has_compile = any(tool in content for tool in ['cargo build', 'cmake', 'meson', 'make '])
    is_generic = is_any or not has_compile

    matrix.append({
        'package': pkg,
        'target': {
            'arch': 'generic' if is_generic else 'v3',
            'profile': 'docker-makepkg-v3',
            'pkgcarch': 'any' if is_any else ('x86_64' if is_generic else 'x86_64_v3'),
            'db': 'tinhiem'
        }
    })
    if not is_generic:
        matrix.append({
            'package': pkg,
            'target': {
                'arch': 'v4',
                'profile': 'docker-makepkg-v4',
                'pkgcarch': 'x86_64_v4',
                'db': 'tinhiem-v4'
            }
        })

print(json.dumps(matrix))
