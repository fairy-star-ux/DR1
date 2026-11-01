"""Hardware-free protocol/API regressions using mocked serial and MMIO."""
import importlib.util
import io
import json
import os
from pathlib import Path
from types import SimpleNamespace
import unittest
from unittest.mock import patch

SOURCE = Path(__file__).resolve().parents[1] / 'linux/app/boat_web_server.py'
with patch.dict(os.environ, {'FPGA_SERVO_MMIO_BASE': ''}):
    spec = importlib.util.spec_from_file_location('boat_web', str(SOURCE))
    web = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(web)

class WebTests(unittest.TestCase):
    def post(self, path, body):
        data = json.dumps(body).encode()
        handler = SimpleNamespace(path=path, headers={'Content-Length': str(len(data))}, rfile=io.BytesIO(data))
        with patch.object(web, 'json_response') as response:
            web.Handler.do_POST(handler)
        args = response.call_args[0]
        return args[1], args[2] if len(args) > 2 else 200

    def test_angle_bounds(self):
        for value in [0, 90, 180]:
            self.assertEqual(web.servo_angle(value, 'test'), value)
        for value in [-1, 181, True, 90.1, '90', None]:
            with self.assertRaises(ValueError):
                web.servo_angle(value, 'test')

    def test_unconfigured_mmio_never_opens_mem(self):
        with patch.object(web.os, 'open') as opened:
            with self.assertRaises(RuntimeError):
                web.servo_mmio_write(0, 90)
        opened.assert_not_called()

    def test_nmea_rmc(self):
        item = web.parse_nmea('$GNRMC,123519,A,4807.038,N,01131.000,E,2.5,0,010100,,,A*00')
        self.assertTrue(item['fix'])
        self.assertAlmostEqual(item['lat'], 48.1173)
        self.assertAlmostEqual(item['lon'], 11.5166666667)
        self.assertEqual(item['speed_knots'], 2.5)

    def test_nmea_no_fix(self):
        item = web.parse_nmea('$GNGGA,,,,,,0,00,25.5,,,,,,*64')
        self.assertFalse(item['fix'])
        self.assertIsNone(item['lat'])
        self.assertIsNone(web.parse_nmea('noise'))
        self.assertIsNone(web.parse_nmea('$GPTXT,01,01,01,ANTENNA OK*35'))
        self.assertLess(web.nmea_coord('4807.038', 'S'), 0)

    def test_ptz_offsets(self):
        with patch.object(web, 'servo_mmio_write') as mmio:
            body, code = self.post('/api/ptz', {'pan': 80, 'tilt': 100})
        self.assertEqual(code, 200)
        self.assertTrue(body['ok'])
        self.assertEqual([c[0] for c in mmio.call_args_list], [(0, 80), (4, 100)])

    def test_invalid_ptz_does_not_touch_hardware(self):
        with patch.object(web, 'servo_mmio_write') as mmio:
            _, code = self.post('/api/ptz', {'pan': 90, 'tilt': 200})
        self.assertEqual(code, 400)
        mmio.assert_not_called()

    def test_ultrasonic_modes(self):
        for enable, sweep, control in [(True, False, 1), (True, True, 3), (False, True, 0), (False, False, 0)]:
            with patch.object(web, 'servo_mmio_write') as mmio:
                _, code = self.post('/api/ultrasonic', {'angle': 75, 'enable': enable, 'sweep': sweep})
            self.assertEqual(code, 200)
            self.assertEqual([c[0] for c in mmio.call_args_list], [(8, 75), (12, control)])

    def test_ultrasonic_boolean_validation(self):
        with patch.object(web, 'servo_mmio_write') as mmio:
            _, code = self.post('/api/ultrasonic', {'enable': 'false'})
        self.assertEqual(code, 400)
        mmio.assert_not_called()

    def test_motor_two_channels_and_clamp(self):
        with patch.object(web, 'serial_fd', return_value=42), patch.object(web.os, 'write') as written, patch.object(web.os, 'close'):
            ok, command = web.motor_command([3000, 0, 3000, 0])
            self.assertTrue(ok)
            self.assertEqual(command, '$pwm:3000,0,3000,0#')
            written.assert_called_once_with(42, command.encode())
            _, command = web.motor_command([20000, 0, -20000, 0])
            self.assertEqual(command, '$pwm:10000,0,-10000,0#')

    def test_invalid_motor_shape(self):
        with patch.object(web, 'motor_command') as motor:
            _, code = self.post('/api/motor', {'pwm': [1, 2]})
        self.assertEqual(code, 400)
        motor.assert_not_called()

    def test_disabled_ptz_returns_unavailable(self):
        _, code = self.post('/api/ptz', {'pan': 90, 'tilt': 90})
        self.assertEqual(code, 503)

    def test_unknown_api(self):
        _, code = self.post('/api/not-present', {})
        self.assertEqual(code, 404)

if __name__ == '__main__':
    unittest.main()
