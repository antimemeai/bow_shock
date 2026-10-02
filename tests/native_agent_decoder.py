#!/usr/bin/env python3
"""Direct actual Foundation agent-reply decoder boundaries."""
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='bow-native-agent-decode-') as temporary:
    binary = Path(temporary) / 'probe'
    subprocess.run(['clang++', '-std=c++17', '-fobjc-arc', '-Wall', '-Wextra', '-Werror',
                    '-framework', 'Foundation', '-I', str(ROOT / 'native/cef'),
                    str(ROOT / 'tests/native_agent_decoder_probe.mm'),
                    str(ROOT / 'native/cef/continuous_clock.mm'), '-o', str(binary)], check=True)
    subprocess.run([str(binary)], check=True, timeout=5)
