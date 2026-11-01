#!/usr/bin/env python3
"""Stage project configuration in an existing official SDK; no device writes."""
import argparse
from pathlib import Path
import re
import shutil

REPO = Path(__file__).resolve().parents[1]

def replace_config(text, key, value):
    pattern = r'^(?:' + re.escape(key) + r'=.*|# ' + re.escape(key) + r' is not set)$'
    line = key + '=' + value
    return re.sub(pattern, lambda _: line, text, flags=re.M) if re.search(pattern, text, re.M) else text + '\n' + line + '\n'

def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('sdk', type=Path)
    ap.add_argument('--enable-fpga-servos', action='store_true', help='Only with the matching BOOT.bin/bitstream')
    ap.add_argument('--wifi-config', type=Path, help='Private wpa_supplicant.conf, never committed')
    ap.add_argument('--root-password-file', type=Path, required=True, help='Private one-line password file')
    args = ap.parse_args()
    sdk = args.sdk.resolve()
    br = sdk / 'sources/buildroot'
    kernel = sdk / 'sources/linux'
    assert (br / 'Makefile').is_file() and (kernel / 'Makefile').is_file(), 'Official SDK not found'
    assert (kernel / 'localversion-rt').read_text().strip() == '-rt42', 'Use the matching vendor Linux source tree'
    stage = sdk / 'boards/DR1M/boat-overlay'
    if args.wifi_config:
        assert args.wifi_config.is_file(), 'Private WiFi config not found'
    else:
        assert not (stage / 'etc/wpa_supplicant.conf').exists(), 'Existing private WiFi config found; pass --wifi-config explicitly'
    password = args.root_password_file.read_text().strip()
    assert password and not any(c in password for c in '\n\r"\\'), 'Use a nonempty password without quote/backslash/newline'
    # Copy only allowlisted project files; don't copy live /etc or SSH host keys.
    source = REPO / 'linux/buildroot/rootfs_overlay'
    for path in source.rglob('*'):
        if path.is_file() and not path.name.endswith('.example'):
            out = stage / path.relative_to(source)
            out.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(str(path), str(out))
    app = stage / 'usr/local/bin/boat_web_server.py'
    app.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(str(REPO / 'linux/app/boat_web_server.py'), str(app))
    config = (REPO / 'linux/buildroot/configs/buildroot.config').read_text()
    config = replace_config(config, 'BR2_ROOTFS_OVERLAY', '"' + str(stage) + '"')
    config = replace_config(config, 'BR2_TOOLCHAIN_EXTERNAL_PATH', '"' + str(sdk / 'tools/aarch64-linux') + '"')
    config = replace_config(config, 'BR2_DEFCONFIG', '"' + str(br / 'configs/anlogic_dr1_buildroot_defconfig') + '"')
    config = replace_config(config, 'BR2_TARGET_GENERIC_ROOT_PASSWD', '"' + password + '"')
    (br / '.config').write_text(config)
    defaults = stage / 'etc/default/boat-web'
    text = defaults.read_text()
    text = re.sub(r'^#?\s*(?:export\s+)?FPGA_SERVO_MMIO_BASE=.*$',
                  'FPGA_SERVO_MMIO_BASE=0x80010000' if args.enable_fpga_servos else '# FPGA_SERVO_MMIO_BASE=0x80010000', text, flags=re.M)
    defaults.write_text(text)
    if args.wifi_config:
        shutil.copy2(str(args.wifi_config), str(stage / 'etc/wpa_supplicant.conf'))
        (stage / 'etc/wpa_supplicant.conf').chmod(0o600)
    for path in (stage / 'etc/init.d').glob('S*'):
        path.chmod(0o755)
    shutil.copy2(str(REPO / 'linux/kernel/configs/linux.config'), str(kernel / '.config'))
    # The official source tree carries localversion-rt; keep that single suffix.
    target = kernel / 'arch/arm64/boot/dts/anlogic'
    target.mkdir(parents=True, exist_ok=True)
    for path in (REPO / 'linux/kernel/dts').iterdir():
        if path.is_file():
            shutil.copy2(str(path), str(target / path.name))
    print('SDK configuration staged. MMIO enabled:', args.enable_fpga_servos)
    print('Private root password is written only to SDK .config; do not commit SDK output.')

if __name__ == '__main__':
    main()
