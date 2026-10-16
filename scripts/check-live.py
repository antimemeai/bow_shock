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
    parser.add_argument('--expect-link', help='An exact rendered link destination expected on this live page.')
    parser.add_argument('--expect-preview-text', action='append', default=[], help='A concrete value expected in the actual extraction preview; repeat as needed.')
    parser.add_argument('--objective', help='Run a real Blackbird turn with the captured page.')
    parser.add_argument('--blackbird', type=Path)
    parser.add_argument('--app', type=Path)
    parser.add_argument('--extraction', action='store_true', help='Inspect actual structured extraction and rendered previews after one revision.')
    parser.add_argument('--timeout', type=float, help='Optional automation timeout in seconds; ordinary readings wait for completion or Stop.')
    args = parser.parse_args()
    artifacts = ROOT / 'context/runtime/live-checks'
    artifacts.mkdir(parents=True, exist_ok=True)
    data = Path(tempfile.mkdtemp(prefix='run-', dir=artifacts))
    output = data / 'result.plist'
    command = [sys.executable, str(ROOT / 'scripts/try-poc.py'), args.url,
               '--data-dir', str(data), '--smoke-output', str(output)]
    if args.blackbird:
        command += ['--blackbird', str(args.blackbird)]
    if args.app:
        command += ['--app', str(args.app)]
    if args.extraction:
        if not args.objective:
            parser.error('--extraction requires --objective.')
        command += ['--smoke-extraction']
    if args.objective:
        command += ['--smoke-objective', args.objective]
    print(f'Live run: {data}', flush=True)
    with (data / 'app.stderr').open('wb') as errors:
        process = subprocess.Popen(command, cwd=ROOT, stderr=errors, start_new_session=True)
        try:
            process.wait(timeout=args.timeout)
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
    reference = result['page']['reading']
    directory = Path(reference['directory'])
    with Path(reference['manifest_path']).open('rb') as stream:
        page = plistlib.load(stream)
    assert page['format'] == 'oxcart.reading' and page['version'] == 1
    assert (directory / page['snapshot_file']).is_file()
    assert (directory / 'README.txt').is_file()
    views = page['documents']
    view = next((view for view in views if view['frame_id'] == page['frame_id']), views[0])
    text = (directory / view['text_file']).read_text()
    with (directory / view['blocks_file']).open('rb') as stream:
        blocks = plistlib.load(stream)
    if not text.strip() or result['block_count'] < 1:
        raise AssertionError(('empty live capture', data))
    if not page['url'].startswith(('https://', 'http://')):
        raise AssertionError(('unexpected URL', page['url']))
    if not 0 < page['capture_start_ns'] <= page['capture_end_ns']:
        raise AssertionError('invalid actual capture interval')
    if not page['document_id'] or not page['frame_id'] or not page['coverage']:
        raise AssertionError('missing actual capture identity/coverage')
    if args.expect_text and args.expect_text.casefold() not in text.casefold():
        raise AssertionError(('expected live text absent', args.expect_text, data))
    if args.expect_link and args.expect_link not in blocks['link_url']:
        raise AssertionError(('expected rendered link absent', args.expect_link, data))
    if args.objective and not args.extraction and (result.get('outcome') != 'completed' or not result.get('answer', '').strip()):
        raise AssertionError(('Blackbird request failed', result.get('outcome'), result.get('blackbird_error'), data))
    print(f'Captured {page["title"]!r}: {len(views)} documents, '
          f'{result["block_count"]} blocks, {reference["text_bytes"]} UTF-8 text bytes; {directory}', flush=True)
    if args.extraction:
        extraction = result.get('extraction', {})
        if not extraction.get('valid') or extraction.get('phase') != 'tweak' or result.get('extraction_error'):
            raise AssertionError(('extraction failed', result, data))
        attempt = Path(extraction['directory'])
        with (attempt / 'received.bplist').open('rb') as stream:
            document = plistlib.load(stream)
        assert document['format'] == 'oxcart.extraction' and document['blocks']
        assert (attempt / 'preview.txt').read_text().strip()
        preview_text = (attempt / 'preview.txt').read_text()
        for expected in args.expect_preview_text:
            if expected.casefold() not in preview_text.casefold():
                raise AssertionError(('expected extraction value absent', expected, attempt))
        assert (attempt / 'preview.pdf').read_bytes().startswith(b'%PDF-')
        assert (attempt / 'preview.rtf').is_file() and (attempt / 'preview.bplist').is_file()
        with (attempt / 'attempt.bplist').open('rb') as stream:
            manifest = plistlib.load(stream)
        previous = Path(manifest['predecessor_directory'])
        assert (previous / 'preview.txt').is_file() and (previous / 'received.bplist').is_file()
        print('Extraction preview: ' + str(attempt))
    elif args.objective:
        print('Blackbird: ' + result['answer'], flush=True)


if __name__ == '__main__':
    main()
