#!/usr/bin/env python3
"""Open a live site in Oxcart with its native Blackbird conversation panel."""
import argparse
from pathlib import Path
import shutil
import subprocess
import sys
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('url', nargs='?', default='https://news.ycombinator.com/')
    parser.add_argument('--data-dir', type=Path, default=ROOT / 'context/runtime/live')
    parser.add_argument('--blackbird', type=Path, help='Blackbird executable with --application support.')
    parser.add_argument('--model', default='gpt-6.1-sol')
    parser.add_argument('--smoke-output', type=Path, help='Read the live page, save a binary plist report and exit.')
    parser.add_argument('--smoke-objective', help='Also send the live page and this objective to Blackbird before exiting.')
    options = parser.parse_args()
    parsed = urlsplit(options.url)
    if parsed.scheme not in ('http', 'https') or not parsed.hostname:
        parser.error('Choose an HTTP or HTTPS live site URL.')
    app = ROOT / 'context/build/native/Bow Shock.app/Contents/MacOS/Bow Shock'
    if sys.platform != 'darwin' or not app.is_file():
        parser.error('Build the macOS app with python3 scripts/build-native.py first.')
    candidates = [
        Path.home() / 'projects/blackbird-oxcart/build/release/blackbird',
        Path.home() / 'projects/blackbird-oxcart/build/debug/blackbird',
        Path.home() / 'projects/blackbird/build/release/blackbird',
    ]
    selected = options.blackbird or next((path for path in candidates if path.is_file()), None)
    if selected is None:
        command = shutil.which('blackbird')
        selected = Path(command) if command else candidates[-1]
    selected = selected.expanduser().resolve()
    if not selected.is_file() and options.smoke_objective:
        parser.error('Build Blackbird or select --blackbird to send a request.')
    if options.smoke_objective and not options.smoke_output:
        parser.error('--smoke-objective requires --smoke-output.')
    data = options.data_dir.expanduser().resolve()
    data.mkdir(parents=True, exist_ok=True)
    command = [str(app), f'--bs-profile={data / "profile"}', f'--bs-url={options.url}',
               f'--ox-blackbird={selected}', f'--ox-session={data / "blackbird"}',
               f'--ox-cwd={ROOT}', f'--ox-model={options.model}']
    if options.smoke_output:
        output = options.smoke_output.expanduser().resolve()
        output.parent.mkdir(parents=True, exist_ok=True)
        command.append(f'--ox-smoke-output={output}')
    if options.smoke_objective:
        command.append(f'--ox-smoke-objective={options.smoke_objective}')
    print(f'Oxcart: {options.url}\nBlackbird: {selected}\nSession: {data / "blackbird"}', flush=True)
    child = subprocess.Popen(command, start_new_session=not bool(options.smoke_output))
    while True:
        try:
            return child.wait()
        except KeyboardInterrupt:
            print('Quit Oxcart from its application menu or close its browser windows.', flush=True)


if __name__ == '__main__':
    raise SystemExit(main())
