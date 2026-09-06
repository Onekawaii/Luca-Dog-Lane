#!/usr/bin/env python3
from __future__ import annotations

import base64
import hashlib
import io
import lzma
import os
import pathlib
import subprocess
import sys
import tarfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
PAYLOAD_B64 = ROOT / '.bootstrap' / 'payload.b64'
EXPECTED_XZ_SHA256 = '794ab2bec04cd68ac2a4b597f844777171f569c8636abc0d31a8b361e7aa65d9'


def main() -> None:
    encoded = PAYLOAD_B64.read_text(encoding='ascii').strip()
    raw_xz = base64.b64decode(encoded)
    actual = hashlib.sha256(raw_xz).hexdigest()
    if actual != EXPECTED_XZ_SHA256:
        raise SystemExit(f'bootstrap payload hash mismatch: {actual} != {EXPECTED_XZ_SHA256}')

    tar_bytes = lzma.decompress(raw_xz)
    with tarfile.open(fileobj=io.BytesIO(tar_bytes), mode='r:') as tf:
        members = tf.getmembers()
        for member in members:
            target = (ROOT / member.name).resolve()
            if ROOT != target and ROOT not in target.parents:
                raise SystemExit(f'unsafe payload member: {member.name}')
        tf.extractall(ROOT)
    print(f'materialized {len(members)} source files')

    from PIL import Image
    staged = ROOT / '.bootstrap_assets' / 'breakroom_battlemap_q10.jpg'
    target = ROOT / 'campaigns' / 'strawberry_omen' / 'assets' / 'maps' / 'breakroom_battlemap_v0.png'
    target.parent.mkdir(parents=True, exist_ok=True)
    with Image.open(staged) as im:
        im.convert('RGB').save(target, 'PNG', optimize=True)
    print(f'reconstructed {target.relative_to(ROOT)} ({target.stat().st_size} bytes)')

    os.chdir(ROOT)
    subprocess.run([sys.executable, '-m', 'hive_lattice.cli', 'generate-assets', 'strawberry_omen'], check=True)

    manifest = ROOT / 'BUILD_MANIFEST.sha256'
    rows = []
    for p in sorted(ROOT.rglob('*')):
        if not p.is_file():
            continue
        rel = p.relative_to(ROOT).as_posix()
        if rel == 'BUILD_MANIFEST.sha256' or rel.startswith('.git/') or rel.startswith('.bootstrap/') or rel.startswith('.bootstrap_assets/'):
            continue
        if rel.endswith('.pyc') or '/__pycache__/' in f'/{rel}/':
            continue
        h = hashlib.sha256(p.read_bytes()).hexdigest()
        rows.append(f'{h}  {rel}')
    manifest.write_text('\n'.join(rows) + '\n', encoding='utf-8')
    print(f'wrote canonical manifest for {len(rows)} files')


if __name__ == '__main__':
    main()
