"""Validate SDK staging in a temporary fixture, never the user's live SDK."""
import importlib.util
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('configure_sdk', str(ROOT / 'scripts/configure_sdk.py'))
configure = importlib.util.module_from_spec(spec)
spec.loader.exec_module(configure)

class ConfigureTests(unittest.TestCase):
    def test_config_replacement(self):
        self.assertEqual(configure.replace_config('BR2_X="old"\n', 'BR2_X', '"new"'), 'BR2_X="new"\n')
        self.assertEqual(configure.replace_config('# BR2_X is not set\n', 'BR2_X', 'y'), 'BR2_X=y\n')

    def test_sdk_fixture_defaults_and_opt_in(self):
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            sdk = base / 'sdk'
            for relative in ['sources/buildroot/Makefile', 'sources/linux/Makefile', 'sources/linux/localversion-rt']:
                file = sdk / relative
                file.parent.mkdir(parents=True, exist_ok=True)
                file.write_text('-rt42\n' if relative.endswith('localversion-rt') else '# fixture\n')
            password = base / 'password.txt'
            password.write_text('TEST_ONLY_NOT_A_DEPLOYED_PASSWORD\n')
            args = [sys.executable, str(ROOT / 'scripts/configure_sdk.py'), str(sdk), '--root-password-file', str(password)]
            subprocess.run(args, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            defaults = sdk / 'boards/DR1M/boat-overlay/etc/default/boat-web'
            self.assertIn('# FPGA_SERVO_MMIO_BASE=', defaults.read_text())
            self.assertTrue((sdk / 'boards/DR1M/boat-overlay/usr/local/bin/boat_web_server.py').is_file())
            self.assertTrue((sdk / 'sources/linux/arch/arm64/boot/dts/anlogic/anlogic-dr1.dts').is_file())
            config = (sdk / 'sources/buildroot/.config').read_text()
            self.assertIn('BR2_TOOLCHAIN_EXTERNAL_PATH="' + str(sdk / 'tools/aarch64-linux') + '"', config)
            subprocess.run(args + ['--enable-fpga-servos'], check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            self.assertIn('\nFPGA_SERVO_MMIO_BASE=0x80010000', defaults.read_text())

if __name__ == '__main__':
    unittest.main()
