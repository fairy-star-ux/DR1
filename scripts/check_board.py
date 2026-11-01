#!/usr/bin/env python3
"""Read-only Web reachability/schema check; sends GET only, never actuator commands."""
import argparse
import json
import sys
from urllib.request import urlopen

def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('base_url', help='For example http://BOARD_IP:8080')
    args = ap.parse_args()
    base = args.base_url.rstrip('/')
    for endpoint, fields in [('/api/status', ('motor', 'gps', 'fpga')), ('/api/photos', ('files',))]:
        with urlopen(base + endpoint, timeout=5) as r:
            payload = json.load(r)
        if not isinstance(payload, dict) or any(k not in payload for k in fields):
            raise ValueError('Unexpected response schema: ' + endpoint)
        print('PASS GET ' + endpoint)
        if endpoint == '/api/status':
            print(json.dumps({'gps': payload['gps'], 'fpga': payload['fpga']}, ensure_ascii=False, indent=2))
    print('No motion/capture command sent. Configured servo_control does not verify the bitstream.')

if __name__ == '__main__':
    try:
        main()
    except Exception as exc:
        print('FAIL:', exc, file=sys.stderr)
        sys.exit(1)
