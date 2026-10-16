#!/usr/bin/env python3
"""Run native extraction/preview against an already saved complete reading."""
import argparse
from pathlib import Path
import subprocess
import uuid

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('reading', type=Path)
parser.add_argument('--blackbird', type=Path, required=True)
parser.add_argument('--data-dir', type=Path)
parser.add_argument('--objective', default='Extract and organize the useful information in this saved visit, preserving source links and describing coverage gaps.')
args = parser.parse_args()
output = ROOT / 'context/build' / f'extract-reading-{uuid.uuid4()}'
output.parent.mkdir(parents=True, exist_ok=True)
sources = ['extraction_workspace.mm', 'extraction_preview.mm', 'extraction_controller.mm',
           'blackbird_connection.mm', 'blackbird_packet.mm']
subprocess.run([
    '/usr/bin/clang++', '-std=c++20', '-fobjc-arc', '-fblocks', '-Wall', '-Wextra', '-Werror',
    '-framework', 'Cocoa', *(str(ROOT / 'native/cef' / name) for name in sources),
    str(ROOT / 'native/tools/extract_reading.mm'), '-o', str(output),
], check=True, cwd=ROOT)
data = args.data_dir.expanduser().resolve() if args.data_dir else ROOT / 'context/runtime/retained-extractions' / str(uuid.uuid4())
raise SystemExit(subprocess.run([str(output), str(args.blackbird.expanduser().resolve()),
                               str(args.reading.expanduser().resolve()), str(data), str(ROOT),
                               args.objective], cwd=ROOT).returncode)
