#!/usr/bin/env python3
"""Actual native tandem proposal, explicit Use/Save gates and SQLite reopen."""
import argparse
import json
import os
from pathlib import Path
import sqlite3
import subprocess
import sys
import tempfile
import time
import shutil
import signal

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'scripts'))
from fixture_service import arguments, serve
from native_table_workflow import run as reopen
APP = ROOT / 'context/build/native/Bow Shock.app/Contents/MacOS/Bow Shock'


def zero_rows(data):
    with sqlite3.connect(f'file:{data / "tables.sqlite"}?mode=ro', uri=True) as db:
        assert db.execute('select count(*) from rows').fetchone() == (0,)
        assert db.execute('select count(*) from commits').fetchone() == (0,)


def run(data, origin, executable, model, controlled=False, stop=False, control_loss=False, close=False, clock_observer=False):
    output = data / 'agent.json'
    mode = 'agent-close' if close else 'agent-control-loss' if control_loss else 'agent-stop' if stop else 'agent'
    args = arguments(APP, data, origin) + [f'--bs-smoke-output={output}', f'--bs-table-smoke={mode}',
        f'--bs-agent-executable={executable}', f'--bs-agent-cwd={data if controlled else ROOT}',
        f'--bs-agent-user-home={data if controlled else Path.home()}', f'--bs-agent-home={data if controlled else Path.home() / ".codex"}',
        f'--bs-agent-model={model}']
    proposal = review = None
    helper_killed = False
    agent_pids = set()
    missed_process_samples = 0
    next_process_sample = 0
    observer = None
    if clock_observer:
        from clock_startup_observer import ClockStartupObserver
        observer = ClockStartupObserver(APP, APP.parent / 'bow-shock-controller',
                                        APP.parent / 'bow_shock_clock_probe', data / 'clock-observation')
    errors = data / 'agent.stderr'
    with errors.open('wb') as stream:
        process = subprocess.Popen(args, stdout=subprocess.DEVNULL, stderr=stream)
        limit = time.monotonic() + 90
        try:
            if observer:
                observer.start(process.pid)
            while process.poll() is None and time.monotonic() < limit:
                if not controlled and time.monotonic() >= next_process_sample:
                    next_process_sample = time.monotonic() + .1
                    try:
                        rows = subprocess.check_output(['/bin/ps', '-axww', '-o', 'pid=,ppid=,comm='], text=True, timeout=1)
                    except (subprocess.TimeoutExpired, subprocess.CalledProcessError):
                        missed_process_samples += 1
                        rows = ''
                    processes = [line.strip().split(None, 2) for line in rows.splitlines()]
                    controllers = {int(row[0]) for row in processes if len(row) == 3 and
                                   int(row[1]) == process.pid and
                                   row[2] == str(APP.parent / 'bow-shock-controller')}
                    agent_pids.update(int(row[0]) for row in processes if len(row) == 3 and
                                      int(row[1]) in controllers and row[2] == str(executable))
                if close and (data / 'peer-before-export').exists() and not Path(str(output) + '.close').exists():
                    zero_rows(data)
                    Path(str(output) + '.close').write_text('close\n')
                runtime_path = Path(str(output) + '.runtime-ready')
                if control_loss and not helper_killed and runtime_path.exists() and (data / 'peer-before-export').exists():
                    runtime = json.loads(runtime_path.read_text())
                    pid = runtime['control_pid']
                    row = subprocess.run(['/bin/ps', '-p', str(pid), '-o', 'ppid=,args='],
                        capture_output=True, text=True, check=True).stdout.strip().split(None, 1)
                    assert int(row[0]) == process.pid and row[1].startswith(str(APP.parent / 'bow-shock-native-control'))
                    zero_rows(data)
                    os.kill(pid, signal.SIGKILL)
                    helper_killed = True
                if stop and (data / 'peer-export.json').exists() and not Path(str(output) + '.stop').exists():
                    exported = json.loads((data / 'peer-export.json').read_text())
                    assert [f['candidate_id'] for f in exported['page_evidence']] == ['r0f0', 'r0f1']
                    zero_rows(data)
                    Path(str(output) + '.stop').write_text('stop\n')
                proposal_path = Path(str(output) + '.proposal-ready')
                review_path = Path(str(output) + '.review-ready')
                if proposal is None and proposal_path.exists():
                    proposal = json.loads(proposal_path.read_text())
                    zero_rows(data)
                    assert set(proposal['candidate_ids']) == {'r0f0', 'r0f1'}, proposal
                    original = json.loads(proposal['review']['content'])['batch']
                    selected = set(proposal['candidate_ids'])
                    rows = []
                    for r, row in enumerate(original['rows']):
                        fields = [f for n, f in enumerate(row['fields']) if f'r{r}f{n}' in selected]
                        if fields:
                            rows.append({'fields': fields})
                    expected = {'schema_version': original['schema_version'],
                                'pattern_version': original['pattern_version'], 'partial': True, 'rows': rows}
                    assert proposal['batch'] == expected, 'proposal changed original native capture fields or identities'
                    assert 'BS_PRIVATE_MARKER' not in json.dumps(proposal), proposal
                    (Path(str(output) + '.use')).write_text('use\n')
                if review is None and review_path.exists():
                    assert proposal is not None
                    review = json.loads(review_path.read_text())
                    zero_rows(data)
                    assert review['review']['staging_id'] == proposal['review']['staging_id']
                    assert review['review']['version'] == proposal['review']['version'] + 1
                    assert review['publication_guard'] == proposal['source_guard']
                    (Path(str(output) + '.save')).write_text('save\n')
                time.sleep(.01)
            assert process.poll() is not None, 'native tandem acceptance deadline'
        finally:
            try:
                if process.poll() is None:
                    process.terminate()
                    try: process.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        process.kill(); process.wait(timeout=5)
                if not controlled:
                    (data / 'observed-agent-pids.json').write_text(json.dumps({
                        'pids': sorted(agent_pids), 'missed_samples': missed_process_samples}) + '\n')
            finally:
                if observer:
                    observer.stop()
    assert process.returncode == 0, errors.read_text(errors='replace')[-5000:]
    result = json.loads(output.read_text())
    assert 'IGNORED_REASONING_MARKER' not in json.dumps(result), 'intermediate reasoning was published'
    assert 'IGNORED_MCP_MARKER' not in json.dumps(result), 'MCP startup status was published'
    assert result['table_workflow'] == 'pass' and result['table_closed'] and result['cef_shutdown'], result
    for key in ('controller_pid', 'control_pid'):
        try: os.kill(result[key], 0)
        except ProcessLookupError: pass
        else: raise AssertionError(f'owned {key} survived app exit')
    if stop or control_loss or close:
        assert proposal is None and review is None
        if close:
            assert result['close_authority_stopped'] is True
            assert result['close_joined_pending_stop'] is True
            assert not (data / 'peer-export.json').exists(), 'source crossed the retired close fence'
        elif control_loss:
            assert helper_killed and result['control_fault_rust_stopped'] and result['control_fault_cleared']
            assert not (data / 'peer-export.json').exists(), 'source crossed the retired control-fault fence'
        else:
            assert result['agent_stop_cleared'] is True and result['controller_stop_generation'] == 1
        zero_rows(data)
        with sqlite3.connect(f'file:{data / "tables.sqlite"}?mode=ro', uri=True) as db:
            assert db.execute('select dirty from meta').fetchone() == (0,)
        for line in (data / 'peer-pids').read_text().splitlines():
            try: os.kill(int(line), 0)
            except ProcessLookupError: pass
            else: raise AssertionError('owned controlled Codex child survived Stop/exit')
        print(json.dumps({'native_agent_close' if close else 'native_agent_control_loss' if control_loss else 'native_agent_stop': 'pass'}), flush=True)
        return
    assert proposal and review, result
    if not controlled:
        assert agent_pids, 'no actual selected Codex child observed'
        for pid in agent_pids:
            try: os.kill(pid, 0)
            except ProcessLookupError: pass
            else: raise AssertionError('owned installed Codex child survived native exit')
    assert result['displayed_review_content'] == review['review']['content']
    batch = result['saved_batch']
    fields = batch['rows'][0]['fields']
    assert [f['name'] for f in fields] == ['name', 'price'], fields
    assert fields[0]['state']['value'] == 'Amber', fields
    assert fields[1]['state']['value'] == '12.00', fields
    assert fields[1]['state']['source'] == 'USD 12.00', fields
    assert fields[1]['source']['normalization'] == 'usd-decimal2-v1', fields
    assert all(f['source']['fragment'] == f['state']['source'] for f in fields), fields
    assert batch['partial'] is True
    if controlled:
        exported = json.loads((data / 'peer-export.json').read_text())
        assert [f['field'] for f in exported['page_evidence']] == fields, exported
        assert {f['candidate_id'] for f in exported['page_evidence']} == {'r0f0', 'r0f1'}
        assert 'BS_PRIVATE_MARKER' not in json.dumps(exported)
        for line in (data / 'peer-pids').read_text().splitlines():
            try: os.kill(int(line), 0)
            except ProcessLookupError: pass
            else: raise AssertionError('owned controlled Codex child survived native exit')
    with sqlite3.connect(f'file:{data / "tables.sqlite"}?mode=ro', uri=True) as db:
        assert db.execute('select dirty from meta').fetchone() == (0,)
        assert db.execute('select count(*) from rows').fetchone() == (1,)
        stored = db.execute('select id,review from commits').fetchall()
        assert stored == [(result['commit_id'], review['review']['content'])], stored
        assert json.loads(stored[0][1])['batch'] == batch
        assert json.loads(db.execute('select payload from rows').fetchone()[0]) == batch['rows'][0]
    reopened = reopen(data, origin, 'amber', 'reopen')
    assert reopened['commit_ids'] == [result['commit_id']]
    with sqlite3.connect(f'file:{data / "tables.sqlite"}?mode=ro', uri=True) as db:
        assert db.execute('select dirty from meta').fetchone() == (0,)
        assert db.execute('select review from commits').fetchone()[0] == review['review']['content']
    print(json.dumps({'native_agent_workflow': 'pass', 'commit_id': result['commit_id']}), flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--agent-executable', type=Path, default=Path.home() / '.local/bin/codex')
    parser.add_argument('--model', default='gpt-6.1-sol')
    parser.add_argument('--controlled', action='store_true', help='Use the owned synthetic stdio peer; no inference claim.')
    parser.add_argument('--stop', action='store_true', help='Controlled actual native Stop after field handoff.')
    parser.add_argument('--control-loss', action='store_true', help='Controlled actual helper death before field handoff.')
    parser.add_argument('--close', action='store_true', help='Controlled actual native Quit before field handoff.')
    parser.add_argument('--clock-observer', action='store_true',
                        help='Read-only owned-clock diagnosis during controlled Stop; no runtime deadline changes.')
    options = parser.parse_args()
    if (options.stop or options.control_loss or options.close) and not options.controlled:
        parser.error('--stop/--control-loss/--close requires --controlled.')
    if sum([options.stop, options.control_loss, options.close]) > 1:
        parser.error('Choose one controlled fault per run.')
    if options.clock_observer and not (options.controlled and options.stop):
        parser.error('--clock-observer requires --controlled --stop.')
    artifacts = ROOT / 'context/runtime/native-agent-workflow'
    artifacts.mkdir(parents=True, exist_ok=True)
    data = Path(tempfile.mkdtemp(prefix='run-', dir=artifacts))
    print(f'Artifacts: {data}', flush=True)
    server = serve(0)
    try:
        executable = options.agent_executable.resolve()
        model = options.model
        if options.controlled:
            executable = data / 'codex-peer'
            shutil.copyfile(ROOT / 'tests/codex_owned_peer.py', executable)
            executable.chmod(0o700)
            model = 'fixture-model'
            if options.stop:
                (data / 'peer-stop-mode').write_text('hold after actual handoff\n')
            if options.control_loss or options.close:
                (data / 'peer-control-loss-mode').write_text('hold before actual handoff\n')
        run(data, f'http://127.0.0.1:{server.server_port}', executable, model, options.controlled, options.stop, options.control_loss, options.close, options.clock_observer)
    finally:
        server.shutdown(); server.server_close()


if __name__ == '__main__':
    main()
