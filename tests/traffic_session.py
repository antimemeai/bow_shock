#!/usr/bin/env python3
"""Check native traffic command semantics and retained artifacts, without a fake site."""
from pathlib import Path
import subprocess
import uuid
import runpy

ROOT = Path(__file__).resolve().parents[1]
output = ROOT / 'context/build/traffic-session-test'
output.parent.mkdir(parents=True, exist_ok=True)
subprocess.run([
    '/usr/bin/clang++', '-std=c++20', '-fobjc-arc', '-fblocks', '-Wall', '-Wextra', '-Werror',
    '-framework', 'Foundation', str(ROOT / 'native/cef/extraction_workspace.mm'),
    str(ROOT / 'native/cef/traffic_session.mm'), str(ROOT / 'native/tests/traffic_session_test.mm'),
    '-o', str(output),
], check=True, cwd=ROOT)
artifacts = ROOT / 'context/build/traffic-checks' / str(uuid.uuid4())
artifacts.mkdir(parents=True)
subprocess.run([str(output), str(artifacts)], check=True, cwd=ROOT, timeout=60)
inspector = runpy.run_path(str(ROOT / 'scripts/traffic-inspect.py'))
session = next(path for path in artifacts.iterdir() if path.is_dir() and (path / 'session.bplist').is_file())
report = inspector['inspect'](session)
assert not report['read_errors'], report['read_errors']
assert sum(report['accepted_decisions'].values()) == 6
assert sum(report['rejected_decisions'].values()) == 1
for index, path in enumerate((session / 'bodies').glob('*.bplist')):
    manifest = inspector['read'](path)
    exported = artifacts / f'body-{index}.bin'
    inspector['reconstruct'](session, path, exported)
    if manifest['network_id'] == 'n-1':
        assert exported.read_bytes() == b'abc\0\xff'
    elif manifest['network_id'] == 'fallback':
        assert exported.stat().st_size == 1024 * 1024 + 29
        with exported.open('rb') as source:
            source.seek(-1, 2)
            assert source.read() == bytes([193])
partials = [path for path in (session / 'pauses').glob('*/upstream-body.bplist')
            if inspector['read'](path)['outcome'] == 'cancelled_partial']
assert partials
partial = next(path for path in partials if inspector['read'](path)['bytes'] > 0)
try:
    inspector['reconstruct'](session, partial, artifacts / 'unmarked-partial.bin')
    raise AssertionError('Partial export was accepted without an explicit request')
except ValueError:
    pass
inspector['reconstruct'](session, partial, artifacts / 'partial.bin', allow_partial=True)
assert (artifacts / 'partial.bin').read_bytes() == b'first chunk'
try:
    inspector['reconstruct'](session, partial, artifacts / 'partial.bin', allow_partial=True)
    raise AssertionError('Export overwrote an existing file')
except FileExistsError:
    pass
print('Archive inspection and exact/partial body reconstruction passed')
