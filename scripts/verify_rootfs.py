#!/usr/bin/env python3
"""Validate final rootfs archive content instead of stale build target folders."""
import ast
import argparse
from pathlib import Path, PurePosixPath
import subprocess
import sys
import tarfile

def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('archive', type=Path)
    ap.add_argument('--match-repo', action='store_true', help='Reject stale Web/startup sources in a newly built rootfs')
    args = ap.parse_args()
    archive = args.archive
    with tarfile.open(str(archive), 'r:gz') as tar:
        members = {}
        for item in tar.getmembers():
            assert not item.name.startswith('/') and '..' not in PurePosixPath(item.name).parts, item.name
            name = item.name
            while name.startswith('./'):
                name = name[2:]
            members[name] = item
        required = ['etc/init.d/S35usb-serial', 'etc/init.d/S40aic-wifi', 'etc/init.d/S99boat-web',
                    'etc/default/boat-web', 'usr/local/bin/boat_web_server.py', 'usr/local/bin/camera_capture',
                    'usr/bin/python3', 'usr/sbin/wpa_supplicant', 'sbin/depmod',
                    'lib/modules/6.1.111-rt42/modules.dep',
                    'lib/modules/6.1.111-rt42/extra/aic_load_fw.ko',
                    'lib/modules/6.1.111-rt42/extra/aic8800_fdrv.ko',
                    'lib/modules/6.1.111-rt42/kernel/drivers/usb/serial/ch341.ko',
                    'lib/modules/6.1.111-rt42/kernel/drivers/usb/serial/usbserial.ko',
                    'lib/firmware/aic8800D80/fw_patch_table_8800d80_u02.bin']
        for name in required:
            assert name in members, 'Missing: ' + name
        ast.parse(tar.extractfile(members['usr/local/bin/boat_web_server.py']).read().decode())
        elf = tar.extractfile(members['usr/local/bin/camera_capture']).read()
        assert elf[:4] == b'\x7fELF' and int.from_bytes(elf[18:20], 'little') == 183, 'camera_capture must be AArch64 ELF'
        for name in required[:3]:
            item = members[name]
            assert item.mode & 0o111, 'Not executable: ' + name
            subprocess.run(['sh', '-n'], input=tar.extractfile(item).read(), check=True)
        if args.match_repo:
            repo = Path(__file__).resolve().parents[1]
            expected = {'usr/local/bin/boat_web_server.py': repo / 'linux/app/boat_web_server.py'}
            for name in required[:3]:
                expected[name] = repo / 'linux/buildroot/rootfs_overlay' / name
            for name, source in expected.items():
                actual = tar.extractfile(members[name]).read().replace(b'\r\n', b'\n')
                assert actual == source.read_bytes().replace(b'\r\n', b'\n'), 'Stale source in archive: ' + name
        # Absolute rootfs links such as /bin/busybox are valid here; tar isn't extracted by this check.
        print('PASS: complete rootfs, Web, startup scripts, AArch64 camera, USB serial, WiFi and depmod')
        print('Check WiFi credentials and root password privately; do not publish rootfs archives.')

if __name__ == '__main__':
    main()
