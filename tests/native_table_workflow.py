#!/usr/bin/env python3
"""Actual CEF → native controls → Rust service → SQLite → clean reopen."""
import argparse
import json
import os
from pathlib import Path
import sqlite3
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'scripts'))
from fixture_service import arguments, serve

APP = ROOT / 'context/build/native/Bow Shock.app/Contents/MacOS/Bow Shock'


def run(data, origin, page, mode):
    output = data / f'{page}-{mode}.json'
    errors = data / f'{page}-{mode}.stderr'
    args = arguments(APP, data, origin, page) + [f'--bs-smoke-output={output}',
                                                f'--bs-table-smoke={mode}']
    with errors.open('wb') as stream:
        process = subprocess.Popen(args, stdout=subprocess.DEVNULL, stderr=stream)
        try:
            process.wait(timeout=45)
        finally:
            if process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait(timeout=5)
    assert process.returncode == 0, errors.read_text(errors='replace')[-5000:]
    result = json.loads(output.read_text())
    assert result.get('table_workflow') == 'pass', result
    assert result.get('table_closed') is True, result
    assert result.get('cef_shutdown') is True, result
    assert result.get('table_panel_visible') is True, result
    assert 'BS_PRIVATE_MARKER' not in json.dumps(result), result
    for key in ['controller_pid', 'control_pid']:
        pid = result[key]
        try:
            os.kill(pid, 0)
        except ProcessLookupError:
            pass
        else:
            raise AssertionError(f'owned child {key}={pid} survived app exit')
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--red-only', action='store_true')
    options = parser.parse_args()
    artifacts = ROOT / 'context/runtime/native-table-workflow'
    artifacts.mkdir(parents=True, exist_ok=True)
    # Keep actual CEF results and diagnostics on both success and failure.
    directory = tempfile.mkdtemp(prefix='run-', dir=artifacts)
    print(f'Artifacts: {directory}', flush=True)
    data = Path(directory)
    server = serve(0)
    origin = f'http://127.0.0.1:{server.server_port}'
    try:
        drafts = run(data, origin, 'amber', 'drafts')
        assert drafts['observations'] == 5 and drafts['stop_cleared_review'] is True, drafts
        reviews = drafts['draft_reviews']
        assert len(reviews) == 6 and len({r['staging_id'] for r in reviews}) == 1, reviews
        assert [r['version'] for r in reviews] == [1, 2, 3, 4, 5, 6], reviews
        assert [json.loads(r['content'])['retention_ms'] for r in reviews] == [600000] + [3600000] * 5, reviews
        with sqlite3.connect(data / 'tables.sqlite') as connection:
            assert connection.execute('SELECT COUNT(*) FROM rows').fetchone() == (0,)
            assert connection.execute('SELECT COUNT(*) FROM commits').fetchone() == (0,)
        amber = run(data, origin, 'amber', 'save')
        if options.red_only:
            return
        birch = run(data, origin, 'birch', 'save')
        reopened = run(data, origin, 'amber', 'reopen')
        assert amber['commit_id'] != birch['commit_id'], (amber, birch)
        assert set(reopened['commit_ids']) == {amber['commit_id'], birch['commit_id']}, reopened
        a = amber['saved_batch']['rows'][0]['fields']
        b = birch['saved_batch']['rows'][0]['fields']
        assert [f['state']['kind'] for f in a] == ['value', 'value', 'empty', 'missing', 'invalid', 'inaccessible'], a
        assert [f['state']['kind'] for f in b] == ['value', 'ambiguous', 'empty', 'value', 'value', 'inaccessible'], b
        assert a[0]['state']['value'] == 'Amber' and b[0]['state']['value'] == 'Birch', (a, b)
        assert b[1]['state']['candidates'] == ['USD 12.00', 'USD 14.00'], b
        assert b[4]['state']['value'] == '7', b
        # Independent storage oracle is completed against the actual service
        # schema after UI joins; native status alone cannot certify durability.
        with sqlite3.connect(data / 'tables.sqlite') as connection:
            tables = {row[0] for row in connection.execute("SELECT name FROM sqlite_master WHERE type='table'")}
            assert {'meta', 'commits', 'rows'} <= tables, tables
            assert connection.execute('SELECT dirty FROM meta WHERE id=1').fetchone() == (0,)
            stored = list(connection.execute('SELECT id,review,state FROM commits ORDER BY id'))
            assert {row[0] for row in stored} == set(reopened['commit_ids']), stored
            assert all(row[2] == 'committed' for row in stored), stored
            exact_reviews = {row[0]: row[1] for row in stored}
            assert exact_reviews[amber['commit_id']] == amber['displayed_review_content'], stored
            assert exact_reviews[birch['commit_id']] == birch['displayed_review_content'], stored
            saved = {row[0]: json.loads(row[1])['batch'] for row in stored}
            assert saved[amber['commit_id']] == amber['saved_batch'], stored
            assert saved[birch['commit_id']] == birch['saved_batch'], stored
            row_payloads = {row[0]: json.loads(row[1]) for row in connection.execute('SELECT commit_id,payload FROM rows')}
            assert row_payloads == {key: batch['rows'][0] for key, batch in saved.items()}, row_payloads
        print(json.dumps({'native_table_workflow': 'pass', 'commit_ids': reopened['commit_ids']}))
    finally:
        server.shutdown()
        server.server_close()


if __name__ == '__main__':
    main()
