#!/usr/bin/env python3
"""Actual AppKit panel state/epoch/grounding oracle; no transport or inference."""
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='bs-agent-panel-') as directory:
    executable = Path(directory) / 'probe'
    subprocess.run(['clang++', '-std=c++20', '-fobjc-arc', '-Wall', '-Wextra', '-Werror',
                    '-I', str(ROOT / 'native/cef'), '-framework', 'AppKit',
                    str(ROOT / 'native/cef/agent_panel.mm'),
                    str(ROOT / 'native/cef/table_connection.mm'),
                    str(ROOT / 'native/cef/continuous_clock.mm'),
                    str(ROOT / 'tests/native_agent_panel_probe.mm'), '-o', str(executable)], check=True)
    subprocess.run([str(executable)], check=True, timeout=20)
