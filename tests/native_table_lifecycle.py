#!/usr/bin/env python3
"""Owned CEF/UI lifecycle fault traces with actual Rust/control/SQLite."""
import argparse
import json
import os
from pathlib import Path
import re
import signal
import sqlite3
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'scripts'))
from fixture_service import arguments, serve

APP = ROOT / 'context/build/native/Bow Shock.app/Contents/MacOS/Bow Shock'


def child_state(pid, parent, database):
    row = subprocess.run(['/bin/ps', '-p', str(pid), '-o', 'ppid=,stat=,args='],
                         capture_output=True, text=True, check=True).stdout.strip()
    parts = row.split(None, 2)
    assert len(parts) == 3 and int(parts[0]) == parent, ('owned child parent', row)
    assert parts[2].startswith(str(APP.parent / 'bow-shock-controller')) and str(database) in parts[2], row
    return parts[1]


def samples(result):
    rows = result['lifecycle_samples']
    return {row['stage']: row for row in rows}


def run(case, origin, artifacts):
    data = Path(tempfile.mkdtemp(prefix=case + '-', dir=artifacts))
    output = data / 'result.json'
    errors = data / 'app.stderr'
    print(f'{case}: {data}', flush=True)
    args = arguments(APP, data, origin) + [f'--bs-smoke-output={output}', f'--bs-table-smoke=lifecycle-{case}']
    held = None
    ready = False
    with errors.open('wb') as stream:
        process = subprocess.Popen(args, stdout=subprocess.DEVNULL, stderr=stream)
        limit = time.monotonic() + 45
        try:
            while process.poll() is None and time.monotonic() < limit:
                text = errors.read_text(errors='replace')
                if case == 'stop' and not ready:
                    match = re.search(r'BS_LIFECYCLE stop_ready app=(\d+) rust=(\d+)', text)
                    if match:
                        assert int(match[1]) == process.pid
                        held = int(match[2])
                        child_state(held, process.pid, data / 'tables.sqlite')
                        os.kill(held, signal.SIGSTOP)
                        stopped = time.monotonic() + 1
                        while not child_state(held, process.pid, data / 'tables.sqlite').startswith('T'):
                            assert time.monotonic() < stopped, 'exact owned Rust child did not stop'
                            time.sleep(.005)
                        (Path(str(output) + '.release')).write_text('release\n')
                        ready = True
                if case == 'stop' and held is not None and 'BS_LIFECYCLE stop_held' in text:
                    assert child_state(held, process.pid, data / 'tables.sqlite').startswith('T')
                    os.kill(held, signal.SIGCONT)
                    held = None
                time.sleep(.005)
            if process.poll() is None:
                subprocess.run(['sample', str(process.pid), '1', '1', '-file', str(data / 'app.sample')],
                               capture_output=True, timeout=4)
                raise AssertionError('owned lifecycle app deadline')
        finally:
            if held is not None:
                try:
                    child_state(held, process.pid, data / 'tables.sqlite')
                    os.kill(held, signal.SIGCONT)
                except (AssertionError, ProcessLookupError, subprocess.CalledProcessError):
                    pass
            if process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill(); process.wait(timeout=5)
    assert process.returncode == 0, errors.read_text(errors='replace')[-5000:]
    result = json.loads(output.read_text())
    assert result.get('native_lifecycle') == 'pass', result
    assert result['table_closed'] is True and result['cef_shutdown'] is True, result
    assert 'BS_PRIVATE_MARKER' not in json.dumps(result), result
    for key in ('controller_pid', 'control_pid'):
        with_absent = result[key]
        try:
            os.kill(with_absent, 0)
        except ProcessLookupError:
            pass
        else:
            raise AssertionError(f'owned {key} survived app exit: {with_absent}')
    s = samples(result)
    with sqlite3.connect(f'file:{data / "tables.sqlite"}?mode=ro', uri=True) as db:
        assert db.execute('SELECT dirty FROM meta').fetchone() == (0,)
        assert db.execute('SELECT COUNT(*) FROM rows').fetchone() == (0,)
        assert db.execute('SELECT COUNT(*) FROM commits').fetchone() == (0,)
    if case == 'browser':
        first, extra = result['browser_ids']
        assert len({first, extra, result['later_browser_id']}) == 3
        assert all(row['visible'] for row in result['lifecycle_windows'])
        assert any(row['browser_id'] == first and row['crashed'] for row in result['lifecycle_renderer_events'])
        assert s['extra_loaded']['browser_id'] == first
        assert s['navigation_started']['source_length'] == 0 and s['navigation_started']['save'] is False
        assert result.get('retired_capture_callbacks', 0) >= 1
        a, b = result['navigation_refs']
        assert a['surface_id'] == b['surface_id'] and a['document_id'] != b['document_id']
        assert s['renderer_terminated']['observe'] is False and s['renderer_terminated']['source_length'] == 0
        assert s['selected_closed']['browser_id'] == 0
        assert s['later_browser_loaded']['browser_id'] == 0 and s['later_browser_loaded']['observe'] is False
    elif case == 'stop':
        assert ready and held is None
        h = s['stop_while_rust_held']
        assert h['rust_generation'] == 0 and h['helper_generation'] == 1 and h['stopping'] is True
        assert all(h[key] is False for key in ('observe', 'save', 'retention', 'refresh', 'saved', 'delete'))
        assert h['source_length'] == h['exact_length'] == 0
        assert s['old_ordinary_callback']['stopping'] is True and s['old_ordinary_callback']['busy'] is False
        assert s['stop_reconciled']['rust_generation'] == s['stop_reconciled']['helper_generation'] == 1
    else:
        assert s['before_review_activation']['review_present'] is True and s['before_review_activation']['save'] is True
        assert s['after_review_activation']['review_present'] is False and s['after_review_activation']['save'] is False
        assert s['after_review_activation']['source_length'] == s['after_review_activation']['exact_length'] == 0
        for stage in ('activation', 'session'):
            assert s['before_' + stage]['source_length'] > 0 and s['before_' + stage]['saved'] is True
            after = s['after_' + stage]
            assert after['source_length'] == after['exact_length'] == after['list_count'] == 0
            assert after['saved'] is False and after['save'] is False
        guard = result['lifecycle_original_guard']
        assert all(item == guard for item in result['lifecycle_read_guards'])
        expired = s['expired_before_wake']
        assert expired['clock']['boot_id'] == guard['boot_id']
        assert expired['clock']['continuous_ns'] >= guard['valid_until_ns'] and expired['source_length'] > 0
        assert s['expired_after_wake']['source_length'] == s['expired_after_wake']['list_count'] == 0
    print(json.dumps({'case': case, 'native_lifecycle': 'pass'}), flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--case', choices=('browser', 'stop', 'display'))
    options = parser.parse_args()
    artifacts = ROOT / 'context/runtime/native-table-lifecycle'
    artifacts.mkdir(parents=True, exist_ok=True)
    server = serve(0)
    try:
        origin = f'http://127.0.0.1:{server.server_port}'
        for case in ([options.case] if options.case else ['browser', 'stop', 'display']):
            run(case, origin, artifacts)
    finally:
        server.shutdown(); server.server_close()


if __name__ == '__main__':
    main()
