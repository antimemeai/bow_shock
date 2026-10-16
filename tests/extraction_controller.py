#!/usr/bin/env python3
"""Exercise the actual coordinator/renderer with controlled model outcomes."""
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
output = ROOT / 'context/build/extraction-controller-test'
output.parent.mkdir(parents=True, exist_ok=True)
sources = ['extraction_workspace.mm', 'extraction_preview.mm', 'extraction_controller.mm',
           'blackbird_connection.mm', 'blackbird_packet.mm']
subprocess.run([
    '/usr/bin/clang++', '-std=c++20', '-fobjc-arc', '-fblocks', '-Wall', '-Wextra', '-Werror',
    '-framework', 'Cocoa', *(str(ROOT / 'native/cef' / name) for name in sources),
    str(ROOT / 'native/tests/extraction_controller_test.mm'), '-o', str(output),
], check=True, cwd=ROOT)
subprocess.run([str(output)], check=True, cwd=ROOT, timeout=90)
