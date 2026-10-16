#!/usr/bin/env python3
"""Exercise Oxcart on an actual live site and inspect its native capture/result."""
import argparse
from pathlib import Path
import plistlib
import os
import signal
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('url')
    parser.add_argument('--expect-text', help='A source text fragment expected on this live page.')
    parser.add_argument('--objective', help='Run a real Blackbird turn with the captured page.')
    parser.add_argument('--blackbird', type=Path)
    args = parser.parse_args()
    artifacts = ROOT / 'context/runtime/live-checks'
    artifacts.mkdir(parents=True, exist_ok=True)
    data = Path(tempfile.mkdtemp(prefix='run-', dir=artifacts))
    output = data / 'result.plist'
    command = [sys.executable, str(ROOT / 'scripts/try-poc.py'), args.url,
               '--data-dir', str(data), '--smoke-output', str(output)]
    if args.blackbird:
        command += ['--blackbird', str(args.blackbird)]
    if args.objective:
        command += ['--smoke-objective', args.objective]
    print(f'Live run: {data}', flush=True)
    with (data / 'app.stderr').open('wb') as errors:
        process = subprocess.Popen(command, cwd=ROOT, stderr=errors, start_new_session=True)
        try:
            process.wait(timeout=110)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGTERM)
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
                process.wait()
            raise RuntimeError(f'Live run timed out; inspect {data / "app.stderr"}') from None
    if process.returncode:
        raise RuntimeError(f'App exited {process.returncode}; inspect {data / "app.stderr"}')
    with output.open('rb') as stream:
        result = plistlib.load(stream)
    for name in ['browser_created', 'browser_closed', 'cef_shutdown']:
        if result.get(name) is not True:
            raise AssertionError((name, result))
    for name in ['timeout', 'load_error', 'capture_error']:
        if name in result:
            raise AssertionError((name, result[name], data))
    page = result['page']
    if not page['text'].strip() or result['block_count'] < 1:
        raise AssertionError(('empty live capture', data))
    if not page['url'].startswith(('https://', 'http://')):
        raise AssertionError(('unexpected URL', page['url']))
    if not 0 < page['capture_start_ns'] <= page['capture_end_ns']:
        raise AssertionError('invalid actual capture interval')
    if not page['document_id'] or not page['frame_id'] or not page['coverage']:
        raise AssertionError('missing actual capture identity/coverage')
    if args.expect_text and args.expect_text.casefold() not in page['text'].casefold():
        raise AssertionError(('expected live text absent', args.expect_text, data))
    if args.objective and (result.get('outcome') != 'completed' or not result.get('answer', '').strip()):
        raise AssertionError(('Blackbird request failed', result.get('outcome'), result.get('blackbird_error'), data))
    print(f'Captured {page["title"]!r}: {result["block_count"]} blocks, '
          f'{len(page["text"].encode())} UTF-8 bytes, truncated={page["truncated"]}', flush=True)
    if args.objective:
        print('Blackbird: ' + result['answer'], flush=True)


if __name__ == '__main__':
    main()
