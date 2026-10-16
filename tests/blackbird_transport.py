#!/usr/bin/env python3
"""Exercise native Blackbird packet/process transport; no browser or web server."""
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
output = ROOT / 'context/build/blackbird-transport-test'
output.parent.mkdir(parents=True, exist_ok=True)
subprocess.run([
    '/usr/bin/clang++', '-std=c++20', '-fobjc-arc', '-fblocks', '-Wall', '-Wextra', '-Werror',
    '-framework', 'Foundation', str(ROOT / 'native/cef/blackbird_packet.mm'),
    str(ROOT / 'native/cef/blackbird_connection.mm'),
    str(ROOT / 'native/tests/blackbird_transport_test.mm'), '-o', str(output),
], check=True, cwd=ROOT)
subprocess.run([str(output)], check=True, cwd=ROOT, timeout=45)
