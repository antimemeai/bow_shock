#!/usr/bin/env python3
"""Build Oxcart's live native browser against the acquired CEF tuple."""
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parent.parent
app = ROOT / 'context/build/native/Bow Shock.app'
processes = subprocess.run(['/usr/bin/pgrep', '-f', '^' + re.escape(str(app)) + '/'],
                           capture_output=True, text=True, timeout=10)
if processes.returncode == 0:
    raise SystemExit(f'Close Oxcart and its helpers before rebuilding (PIDs {processes.stdout.strip()})')
if processes.returncode != 1:
    raise SystemExit('Unable to inspect existing Oxcart processes before rebuilding.')
manifest = json.loads((ROOT / 'runtime/cef-macos-arm64.json').read_text())
if manifest['status'] != 'acquired':
    raise SystemExit('Acquire the pinned CEF runtime first: python3 scripts/cef-runtime.py acquire')
commands = [
    ['cmake', '-S', str(ROOT / 'native/cef'), '-B', str(ROOT / 'context/build/native'),
     '-G', 'Ninja', '-DCMAKE_BUILD_TYPE=Release', f'-DCEF_ROOT={ROOT / manifest["distribution_dir"]}'],
    ['cmake', '--build', str(ROOT / 'context/build/native'), '--target', 'bow_shock', '--parallel', '4'],
]
for command in commands:
    print('+ ' + ' '.join(command), flush=True)
    subprocess.run(command, cwd=ROOT, check=True)
# Remove retired catalog/controller payloads on incremental builds as well.
for name in ['bow_shock_clock_probe', 'bow-shock-controller', 'bow-shock-native-control']:
    (app / 'Contents/MacOS' / name).unlink(missing_ok=True)
plists = [app / 'Contents/Info.plist']
for helper in (ROOT / 'context/build/native/helpers').glob('*.app'):
    destination = app / 'Contents/Frameworks' / helper.name
    if destination.exists():
        shutil.rmtree(destination)
    shutil.copytree(helper, destination, symlinks=True)
    source_file = helper / 'Contents/MacOS' / helper.stem
    staged_file = destination / 'Contents/MacOS' / helper.stem
    with source_file.open('rb') as source, staged_file.open('rb') as staged:
        if hashlib.file_digest(source, 'sha256').digest() != hashlib.file_digest(staged, 'sha256').digest():
            raise SystemExit(f'Staged helper differs from build: {helper.name}')
    plists.append(destination / 'Contents/Info.plist')
for plist in plists:
    subprocess.run(['/usr/bin/plutil', '-convert', 'xml1', str(plist)], check=True)
subprocess.run(['codesign', '--force', '--deep', '--sign', '-', str(app)], check=True)
subprocess.run(['codesign', '--verify', '--deep', '--strict', str(app)], check=True)
