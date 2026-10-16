#!/usr/bin/env python3
"""Direct native persistence and document-boundary checks; no browser fixture."""
from pathlib import Path
import subprocess
import uuid

ROOT = Path(__file__).resolve().parents[1]
output = ROOT / 'context/build/extraction-workspace-test'
output.parent.mkdir(parents=True, exist_ok=True)
subprocess.run([
    '/usr/bin/clang++', '-std=c++20', '-fobjc-arc', '-fblocks', '-Wall', '-Wextra', '-Werror',
    '-framework', 'Cocoa', str(ROOT / 'native/cef/extraction_workspace.mm'),
    str(ROOT / 'native/cef/extraction_preview.mm'),
    str(ROOT / 'native/tests/extraction_workspace_test.mm'), '-o', str(output),
], check=True, cwd=ROOT)
artifacts = ROOT / 'context/build/preview-checks' / str(uuid.uuid4())
subprocess.run([str(output), str(artifacts)], check=True, cwd=ROOT)
print('Native renderer artifacts: ' + str(artifacts))
