#!/usr/bin/env python3
"""Exercise the actual coordinator/renderer with controlled model outcomes."""
from pathlib import Path
import subprocess
import uuid
import plistlib
import sys

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
artifacts = ROOT / 'context/build/controller-checks' / str(uuid.uuid4())
subprocess.run([str(output), str(artifacts)], check=True, cwd=ROOT, timeout=90)
for case, expected in [(0, (3, 0)), (1, (2, 2)), (2, (2, 0)), (3, (2, 2))]:
    workspace = artifacts / f'case-{case}' / 'extraction'
    subprocess.run([sys.executable, str(ROOT / 'scripts/extraction-metrics.py'), str(workspace)],
                   check=True, cwd=ROOT, stdout=subprocess.DEVNULL)
    report = next((workspace / 'reports').glob('*/metrics.bplist'))
    data = plistlib.loads(report.read_bytes())
    assert data['counts']['readable_attempts'] == expected[0]
    assert data['counts']['validation_errors'] == expected[1]
    assert not data['read_errors'], data['read_errors']
    if case == 0:
        assert data['counts']['attempt_phases'] == {'initial': 1, 'tweak': 1, 'manual': 1}
    if case == 2:
        assert data['counts']['model_outcomes'] == {'completed': 1, 'cancelled': 1}
    if case == 3:
        assert all(not item['reported_issues_available'] for item in data['attempts'])
print('Native coordinator and metrics artifacts: ' + str(artifacts))
