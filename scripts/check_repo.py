#!/usr/bin/env python3
"""Offline repository checks. Never opens serial ports, MMIO or network."""
import ast
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]

def source_files():
    ignored = {'.git', 'artifacts', 'secrets', '__pycache__', 'build', 'output'}
    return sorted(p for p in ROOT.rglob('*') if p.is_file() and not any(x in ignored for x in p.relative_to(ROOT).parts))

def main():
    files = source_files()
    errors = []
    for p in files:
        rel = p.relative_to(ROOT).as_posix()
        data = p.read_bytes()
        if len(data) > 10 * 1024 * 1024:
            errors.append(rel + ': oversized source file')
        if p.suffix.lower() in {'.bit', '.elf', '.ko', '.o', '.a', '.gz', '.jpg', '.jpeg', '.hpf'}:
            errors.append(rel + ': generated artifact in source tree')
        if p.name in {'wpa_supplicant.conf', 'id_rsa', 'id_ed25519', '.env'}:
            errors.append(rel + ': private file')
        try:
            text = data.decode('utf-8-sig')
        except UnicodeDecodeError:
            continue  # Some original vendor sources use a legacy encoding.
        if p.suffix == '.py':
            try:
                ast.parse(text, filename=rel)
            except SyntaxError as exc:
                errors.append(str(exc))
        if p.suffix == '.xml':
            try:
                ET.fromstring(text)
            except ET.ParseError as exc:
                errors.append(rel + ': ' + str(exc))
        if re.search(r'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----', text):
            errors.append(rel + ': private key')
        if re.search(r'^BR2_TARGET_GENERIC_ROOT_PASSWD=".+"', text, re.M):
            errors.append(rel + ': populated root password')
        if re.search(r'^\s*psk\s*=\s*(?:"(?!REPLACE_WITH_YOUR_OWN_PASSWORD")[^"]+"|[a-fA-F0-9]{64})\s*$', text, re.M):
            errors.append(rel + ': populated WiFi PSK')
        if re.search(r'^\s*#define\s+ONENET_(?:PRODUCT_ID|DEVICE_NAME|DEVICE_KEY)\s+"[^"<]+"', text, re.M):
            errors.append(rel + ': populated legacy cloud credential')
        if p.suffix == '.md':
            for target in re.findall(r'(?<!!)\[[^\]]*\]\(([^)]+)\)', text):
                if '://' in target or target.startswith('#'):
                    continue
                target = target.split('#')[0]
                if not (p.parent / target).exists():
                    errors.append(rel + ': broken document link ' + target)
    project = ROOT / 'fpga/td/fpga_prj.al'
    # TD .al is XML-like: its vendor format has raw '&' and '::' tag names.
    # Inspect source references without rewriting the native project grammar.
    for path in re.findall(r'<File\s+Path="([^"]+)"', project.read_text(encoding='utf-8')):
        if path and not (project.parent / path).is_file():
            errors.append('TD source missing: ' + path)
    config = (ROOT / 'linux/buildroot/rootfs_overlay/etc/default/boat-web').read_text(encoding='utf-8')
    if re.search(r'^\s*(?:export\s+)?FPGA_SERVO_MMIO_BASE=', config, re.M):
        errors.append('Default MMIO must remain disabled until matching BOOT is installed')
    manifest = ROOT / 'manifests/source-sha256.json'
    if manifest.exists():
        hashes = json.loads(manifest.read_text(encoding='utf-8'))
        for rel, expected in hashes.items():
            path = ROOT / rel
            if not path.is_file() or hashlib.sha256(path.read_bytes().replace(b'\r\n', b'\n')).hexdigest() != expected:
                errors.append('Source hash mismatch: ' + rel)
    if (ROOT / '.git').exists():
        result = subprocess.run(['git', '-C', str(ROOT), 'ls-files', '-z'], stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True)
        for rel in result.stdout.decode().split('\0'):
            if rel.startswith(('artifacts/', 'secrets/')):
                errors.append('Private/generated directory staged: ' + rel)
    if errors:
        print('\n'.join('FAIL: ' + e for e in errors))
        return 1
    print('PASS: %d source files; Python/XML, TD references, document links, credential patterns and MMIO defaults' % len(files))
    print('Credential patterns are a targeted check, not a guarantee about all possible secrets.')
    return 0

if __name__ == '__main__':
    sys.exit(main())
