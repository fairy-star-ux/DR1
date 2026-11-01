#!/usr/bin/env python3
"""Explicitly refresh source LF-normalized hashes and local binary hashes."""
import hashlib
import json
from pathlib import Path
from check_repo import ROOT, source_files

def digest(data):
    return hashlib.sha256(data).hexdigest()

def main():
    excluded = {'manifests/source-sha256.json', 'manifests/artifact-sha256.json', 'manifests/validation-report.json'}
    sources = {}
    for path in source_files():
        relative = path.relative_to(ROOT).as_posix()
        if relative not in excluded:
            sources[relative] = digest(path.read_bytes().replace(b'\r\n', b'\n'))
    output = ROOT / 'manifests'
    (output / 'source-sha256.json').write_text(json.dumps(sources, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
    binaries = {}
    for path in sorted((ROOT / 'artifacts').rglob('*')):
        if path.is_file() and path.relative_to(ROOT / 'artifacts').parts[0] in {'known-good', 'sdk-output', 'runtime-deps'}:
            binaries[path.relative_to(ROOT).as_posix()] = {'sha256': digest(path.read_bytes()), 'bytes': path.stat().st_size}
    if binaries:
        (output / 'artifact-sha256.json').write_text(json.dumps(binaries, indent=2) + '\n', encoding='utf-8')
    print('Recorded %d source hashes and %d local artifact hashes' % (len(sources), len(binaries)))

if __name__ == '__main__':
    main()
