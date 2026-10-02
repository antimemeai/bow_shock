#!/usr/bin/env python3
"""Actual native capture growth, AppKit Stop servicing and observed RSS."""
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import threading
import time

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'scripts'))
from fixture_service import arguments

APP = ROOT / 'context/build/native/Bow Shock.app/Contents/MacOS/Bow Shock'
EVIDENCE = ROOT / 'context/runtime/native-capture-work'


class Workload(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path in ['/amber', '/birch']:
            data = (ROOT / 'fixtures/products' / f'{self.path[1:]}.html').read_bytes()
        else:
            parts = self.path.split('/')
            if len(parts) != 3 or parts[1] not in ['tree', 'text', 'frames', 'child'] or not parts[2].isdigit():
                self.send_error(404)
                return
            count = int(parts[2])
            if count > 524288:
                self.send_error(400)
                return
            base = '<div id="name">Amber</div><div id="price">USD 12.00</div><div id="note"> </div><div id="quantity">many</div><div id="private" style="display:none">BS_PRIVATE_MARKER</div>'
            if parts[1] == 'tree':
                growth = ''.join(f'<span>owned leaf {i}</span>' for i in range(count))
            elif parts[1] == 'text':
                growth = '<p>' + 'x' * count + '</p>'
            elif parts[1] == 'frames':
                growth = ''.join(f'<iframe src="http://localhost:{self.server.server_port}/child/{i}"></iframe>' for i in range(count))
            else:
                base = '<div id="name">BS_CHILD_MARKER</div>'
                growth = '<p>Owned alternate-origin child</p>'
            data = ('<!doctype html><meta charset="utf-8"><title>Owned capture growth</title>' + base + growth).encode()
        self.send_response(200)
        self.send_header('Content-Type', 'text/html; charset=utf-8')
        self.send_header('Content-Length', str(len(data)))
        self.send_header('Cache-Control', 'no-store')
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, *_):
        pass


def sample_owned_rss(parent):
    # Keep only RSS of this still-owned process tree, not unrelated process text.
    raw = subprocess.check_output(['/bin/ps', '-ax', '-o', 'pid=,ppid=,rss='], text=True)
    rows = [tuple(map(int, line.split())) for line in raw.splitlines() if line.strip()]
    owned = {parent}
    for _ in range(8):
        children = {pid for pid, ppid, _ in rows if ppid in owned}
        if children <= owned:
            break
        owned |= children
    rss = {pid: kib for pid, _, kib in rows if pid in owned}
    return rss.get(parent, 0), sum(rss.values()), len(rss)


def run(origin, path):
    name = path.strip('/').replace('/', '-')
    directory = EVIDENCE / name
    directory.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='bow-shock-capture-growth-') as temporary:
        data = Path(temporary)
        output = directory / 'result.json'
        output.unlink(missing_ok=True)
        stderr = directory / 'app.stderr'
        cmd = arguments(APP, data, origin, path.strip('/')) + [f'--bs-smoke-output={output}', '--bs-table-smoke=workload']
        with stderr.open('wb') as errors:
            process = subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=errors)
            peaks = [0, 0, 0]
            start = time.monotonic()
            try:
                while process.poll() is None:
                    if time.monotonic() - start > 45:
                        raise AssertionError(f'owned workload {path} exceeded 45s; native cancellation is not claimed')
                    peaks = [max(a, b) for a, b in zip(peaks, sample_owned_rss(process.pid))]
                    time.sleep(.05)
            finally:
                if process.poll() is None:
                    process.terminate()
                    try:
                        process.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.wait(timeout=5)
        assert process.returncode == 0, stderr.read_text(errors='replace')[-5000:]
        result = json.loads(output.read_text())
        assert result.get('capture_workload') == 'recorded' and result.get('table_closed') is True, result
        assert result['controller_stop_generation'] == 1, result
        encoded = json.dumps(result)
        assert 'BS_PRIVATE_MARKER' not in encoded and 'BS_CHILD_MARKER' not in encoded, result
        for key in ['controller_pid', 'control_pid']:
            try:
                os.kill(result[key], 0)
            except ProcessLookupError:
                pass
            else:
                raise AssertionError(f'owned {key} survived actual app exit')
        target = result['stop_target_ns']
        delays = {key: (result[key] - target) / 1e6 for key in ['stop_handler_ns', 'stop_rust_ack_ns', 'stop_helper_ack_ns']}
        assert all(value >= 0 for value in delays.values()), delays
        record = {'path': path, 'elapsed_s': time.monotonic() - start,
                  'ui_max_gap_ms': result['ui_max_gap_ns'] / 1e6,
                  'stop_delays_ms': delays, 'stop_during_capture': result['stop_during_capture'],
                  'observation_status': result['observation']['status'],
                  'observation_reason': result['observation'].get('reason'),
                  'sampled_app_rss_peak_kib': peaks[0], 'sampled_tree_rss_peak_kib': peaks[1],
                  'sampled_process_count_max': peaks[2]}
        (directory / 'measurements.json').write_text(json.dumps(record, indent=2) + '\n')
        print(json.dumps(record), flush=True)
        return record


def main():
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    server = ThreadingHTTPServer(('127.0.0.1', 0), Workload)
    server.daemon_threads = True
    threading.Thread(target=server.serve_forever, daemon=True).start()
    origin = f'http://127.0.0.1:{server.server_port}'
    try:
        records = [run(origin, path) for path in ['/amber', '/birch', '/tree/64', '/tree/1024', '/tree/8192', '/text/524288', '/frames/8', '/frames/32']]
        (EVIDENCE / 'measurements.json').write_text(json.dumps(records, indent=2) + '\n')
        supported = records[:2]
        assert all(r['observation_status'] == 'partial' and r['ui_max_gap_ms'] < 100 and
                   max(r['stop_delays_ms'].values()) < 100 for r in supported), supported
        host_limits = {'callback_copy_or_queue_limit', 'node_limit', 'layout_limit',
                       'string_limit', 'projection_work_limit', 'projection_limit'}
        assert any(r['observation_reason'] in host_limits for r in records[2:]), 'growth did not demonstrate a known configured host boundary'
        print('Owned immutable catalog servicing target passed; general capture remains disabled.')
    finally:
        server.shutdown()
        server.server_close()


if __name__ == '__main__':
    main()
