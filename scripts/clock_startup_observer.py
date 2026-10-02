"""Read-only, macOS-only diagnosis of one owned app's native clock children.

Import before Popen; start(app.pid), then stop() after the owned app concludes.
No clock warm-up, argv inspection, target signal or runtime timeout change.
Sampling itself can perturb timing and PID validation/sample lookup is nonatomic.
"""
import ctypes
import datetime
import re
import json
import os
from pathlib import Path
import subprocess
import sys
import threading
import time


class _BSD(ctypes.Structure):
    _fields_ = [('words', ctypes.c_uint32 * 12), ('comm', ctypes.c_char * 16),
        ('name', ctypes.c_char * 32), ('tail', ctypes.c_uint32 * 6),
        ('start_sec', ctypes.c_uint64), ('start_usec', ctypes.c_uint64)]


class _Task(ctypes.Structure):
    _fields_ = [('totals', ctypes.c_uint64 * 6), ('counts', ctypes.c_int32 * 12)]


class ProcReader:
    """Matched SDK libproc ABI, validated against actual owned processes."""
    def __init__(self):
        if sys.platform != 'darwin' or ctypes.sizeof(_BSD) != 136:
            raise RuntimeError('unsupported libproc diagnostic ABI')
        self.lib = ctypes.CDLL('/usr/lib/libproc.dylib', use_errno=True)
        self.lib.proc_listchildpids.argtypes = [ctypes.c_int, ctypes.c_void_p, ctypes.c_int]
        self.lib.proc_listchildpids.restype = ctypes.c_int
        self.lib.proc_pidinfo.argtypes = [ctypes.c_int, ctypes.c_int, ctypes.c_uint64,
            ctypes.c_void_p, ctypes.c_int]
        self.lib.proc_pidinfo.restype = ctypes.c_int
        self.lib.proc_pidpath.argtypes = [ctypes.c_int, ctypes.c_void_p, ctypes.c_uint32]
        self.lib.proc_pidpath.restype = ctypes.c_int

    def _bsd(self, pid):
        info = _BSD()
        ctypes.set_errno(0)
        size = self.lib.proc_pidinfo(pid, 3, 0, ctypes.byref(info), ctypes.sizeof(info))
        if size != ctypes.sizeof(info) or info.words[3] != pid:
            return None
        return (int(info.words[3]), int(info.words[4]), int(info.words[5]),
            int(info.start_sec) * 1_000_000 + int(info.start_usec), int(info.words[1]))

    def identity(self, pid):
        before = self._bsd(pid)
        if before is None:
            return None
        buffer = ctypes.create_string_buffer(4096)
        ctypes.set_errno(0)
        length = self.lib.proc_pidpath(pid, buffer, len(buffer))
        if length <= 0 or length >= len(buffer):
            return None
        after = self._bsd(pid)
        # Status may change, but PID/parent/user/birth must survive the path read.
        if after is None or before[:4] != after[:4]:
            return None
        return dict(pid=after[0], ppid=after[1], uid=after[2], birth_us=after[3],
            status=after[4], path=os.path.realpath(os.fsdecode(buffer.value)))

    def children(self, pid):
        buffer = (ctypes.c_int * 256)()
        ctypes.set_errno(0)
        count = self.lib.proc_listchildpids(pid, buffer, ctypes.sizeof(buffer))
        error = ctypes.get_errno()
        # Wrapper returns PID count, not bytes. A full list is conservatively partial.
        if count < 0 or count >= len(buffer) or (count == 0 and error):
            raise OSError(error, 'bounded child list unavailable/partial')
        return [int(value) for value in buffer[:count] if value > 0]

    def task(self, pid):
        info = _Task()
        size = self.lib.proc_pidinfo(pid, 4, 0, ctypes.byref(info), ctypes.sizeof(info))
        if size != ctypes.sizeof(info):
            return None
        return dict(resident_bytes=int(info.totals[1]), user_total_raw=int(info.totals[2]),
            system_total_raw=int(info.totals[3]), threads=int(info.counts[9]))


class ClockStartupObserver:
    def __init__(self, app_path, controller_path, clock_path, artifacts, *, sample_limit=2):
        if not 0 <= sample_limit <= 2:
            raise ValueError('diagnostic sample limit must be 0..2')
        self.reader = ProcReader()
        self.paths = [str(Path(path).resolve()) for path in (app_path, controller_path, clock_path)]
        self.artifacts = Path(artifacts)
        self.artifacts.mkdir(parents=True, exist_ok=True)
        self.timeline_path = self.artifacts / 'clock-timeline.jsonl'
        self.summary_path = self.artifacts / 'clock-summary.json'
        self.prepared = (time.monotonic_ns(), time.time_ns())
        self.sample_limit = sample_limit
        self._stop = threading.Event()
        self._thread = None
        self._sampler_thread = None
        self._clocks = {}
        self._controllers = {}
        self._bytes = 0
        self._event_lock = threading.Lock()
        self.stats = dict(polls=0, gaps=0, samples=0, clocks=0, max_poll_ns=0,
            max_poll_gap_ns=0, min_wall_gap_ns=None, max_wall_gap_ns=0, artifact_capped=False)

    def start(self, app_pid):
        if self._thread is not None:
            raise RuntimeError('observer starts once')
        self._thread = threading.Thread(target=self._run, args=(app_pid,), daemon=True)
        self._thread.start()

    def stop(self):
        self._stop.set()
        if self._thread:
            self._thread.join(timeout=3)
        if self._sampler_thread:
            self._sampler_thread.join(timeout=3)
        summary = dict(self.stats, thread_alive=bool(self._thread and self._thread.is_alive()),
            sampler_thread_alive=bool(self._sampler_thread and self._sampler_thread.is_alive()))
        self.summary_path.write_text(json.dumps(summary, sort_keys=True) + '\n')

    def _emit(self, event, **fields):
        mono, wall = time.monotonic_ns(), time.time_ns()
        record = dict(event=event, mono_ns=mono, wall_ns=wall,
            from_prepare_mono_ns=mono - self.prepared[0],
            from_prepare_wall_ns=wall - self.prepared[1], **fields)
        data = json.dumps(record, sort_keys=True) + '\n'
        with self._event_lock:
            if self._bytes + len(data.encode()) > 1024 * 1024:
                self.stats['artifact_capped'] = True
                return
            with self.timeline_path.open('a') as stream:
                stream.write(data)
            self._bytes += len(data.encode())

    @staticmethod
    def _same(actual, expected):
        return actual is not None and all(actual[key] == expected[key]
            for key in ('pid', 'ppid', 'uid', 'birth_us', 'path'))

    def _bind(self, pid, parent, path):
        identity = self.reader.identity(pid)
        if identity and identity['ppid'] == parent and identity['uid'] == os.getuid() and identity['path'] == path:
            return identity
        return None

    def _sample(self, clock, controller, app):
        if self._sampler_thread and self._sampler_thread.is_alive():
            self._emit('sample_busy_gap', identity=clock)
            self.stats['gaps'] += 1
            return
        if self.stats['samples'] >= self.sample_limit:
            return
        if self._sampler_thread:
            self._sampler_thread.join(timeout=0)
        self.stats['samples'] += 1
        self._sampler_thread = threading.Thread(target=self._collect_sample,
            args=(clock, controller, app), daemon=True)
        self._sampler_thread.start()

    @staticmethod
    def _reported_identity(output, identity):
        with output.open('r', errors='replace') as stream:
            header = stream.read(8192)
        process = re.search(r'^Process:.*\[(\d+)\]$', header, re.M)
        parent = re.search(r'^Parent Process:.*\[(\d+)\]$', header, re.M)
        path = re.search(r'^Path:\s+(.+)$', header, re.M)
        launch = re.search(r'^Launch Time:\s+(.+)$', header, re.M)
        birth_matches = False
        if launch:
            try:
                timestamp = datetime.datetime.strptime(launch[1], '%Y-%m-%d %H:%M:%S.%f %z')
                birth_matches = abs(int(timestamp.timestamp() * 1_000_000) - identity['birth_us']) <= 2000
            except ValueError:
                pass
        return dict(pid_matches=bool(process and int(process[1]) == identity['pid']),
            parent_matches=bool(parent and int(parent[1]) == identity['ppid']),
            path_basename_matches=bool(path and Path(path[1]).name == Path(identity['path']).name),
            birth_matches=birth_matches)

    def _collect_sample(self, clock, controller, app):
        process = None
        output = self.artifacts / f"clock-{clock['pid']}-{clock['birth_us']}.sample.txt"
        errors = output.with_suffix('.stderr')
        launch = (time.monotonic_ns(), time.time_ns())
        try:
            if self._stop.is_set() or not all(self._same(self.reader.identity(identity['pid']), identity)
                    for identity in (app, controller, clock)):
                self.stats['gaps'] += 1
                self._emit('sample_identity_gap', identity=clock)
                return
            self._emit('sample_launch_started', identity=clock)
            with errors.open('wb') as stream:
                launch = (time.monotonic_ns(), time.time_ns())
                process = subprocess.Popen(['/usr/bin/sample', str(clock['pid']), '1', '1',
                    '-file', str(output)], stdin=subprocess.DEVNULL, stdout=stream, stderr=stream)
            self._emit('sample_launch_returned', identity=clock, sampler_pid=process.pid,
                launch_mono_ns=time.monotonic_ns() - launch[0],
                launch_wall_ns=time.time_ns() - launch[1], task=self.reader.task(clock['pid']),
                file=str(output))
            expired = False
            while process.poll() is None:
                expired = time.monotonic_ns() - launch[0] > 2_000_000_000
                if expired or self._stop.wait(.01):
                    process.kill()  # Only this worker's still-owned sampler.
                    break
            exit_code = process.wait()
            reported = self._reported_identity(output, clock) if output.exists() else None
            attributed = reported is not None and all(reported.values())
            capped = []
            for artifact in (output, errors):
                if artifact.exists() and artifact.stat().st_size > 1024 * 1024:
                    with artifact.open('r+b') as stream:
                        stream.truncate(1024 * 1024)
                    capped.append(artifact.name)
            if output.exists() and not attributed:
                output.unlink()  # Do not retain a possibly reused/unattributed target stack.
                self.stats['gaps'] += 1
            self._emit('sample_finished', identity=clock, sampler_pid=process.pid,
                exit=exit_code, tool_expired=expired, reported_identity=reported,
                attributed=attributed, retained_capped=capped,
                target_still_identical=self._same(self.reader.identity(clock['pid']), clock))
        except Exception as error:
            self.stats['gaps'] += 1
            self._emit('sample_error', identity=clock, error_type=type(error).__name__,
                errno=getattr(error, 'errno', None))
        finally:
            if process and process.poll() is None:
                process.kill()
                process.wait()

    def _run(self, app_pid):
        app = None
        previous = self.prepared
        self._emit('observer_started', app_pid=app_pid, paths=self.paths)
        try:
            while not self._stop.is_set() and time.monotonic_ns() - self.prepared[0] < 95_000_000_000:
                begin = time.monotonic_ns()
                now = (begin, time.time_ns())
                mono_gap, wall_gap = now[0] - previous[0], now[1] - previous[1]
                self.stats['max_poll_gap_ns'] = max(self.stats['max_poll_gap_ns'], mono_gap)
                self.stats['max_wall_gap_ns'] = max(self.stats['max_wall_gap_ns'], wall_gap)
                self.stats['min_wall_gap_ns'] = wall_gap if self.stats['min_wall_gap_ns'] is None else min(self.stats['min_wall_gap_ns'], wall_gap)
                if mono_gap > 100_000_000 or wall_gap < 0 or abs(mono_gap - wall_gap) > 50_000_000:
                    self._emit('poll_time_gap', mono_delta_ns=mono_gap, wall_delta_ns=wall_gap)
                previous = now
                self.stats['polls'] += 1
                current = self._bind(app_pid, os.getpid(), self.paths[0])
                if app is None and current:
                    app = current
                    self._emit('app_bound', identity=app)
                if app and not self._same(current, app):
                    self._emit('app_identity_unavailable', identity=app)
                    break
                if app:
                    for pid in self.reader.children(app_pid):
                        controller = self._bind(pid, app_pid, self.paths[1])
                        if controller:
                            key = (pid, controller['birth_us'])
                            if key not in self._controllers:
                                if len(self._controllers) == 16:
                                    self.stats['gaps'] += 1
                                    self._emit('controller_identity_limit')
                                else:
                                    self._controllers[key] = controller
                                    self._emit('controller_seen', identity=controller)
                    live = set()
                    for controller in self._controllers.values():
                        if not self._same(self.reader.identity(controller['pid']), controller):
                            continue
                        for pid in self.reader.children(controller['pid']):
                            clock = self._bind(pid, controller['pid'], self.paths[2])
                            if not clock:
                                continue
                            key = (pid, clock['birth_us'])
                            live.add(key)
                            if key not in self._clocks:
                                if len(self._clocks) == 512:
                                    self._emit('clock_identity_limit')
                                    self.stats['gaps'] += 1
                                    continue
                                self._clocks[key] = dict(identity=clock, first=now, last=now, long=False, missing=False)
                                self.stats['clocks'] += 1
                                self._emit('clock_seen', identity=clock)
                            entry = self._clocks[key]
                            if entry['missing']:
                                self._emit('clock_reobserved', identity=clock)
                                entry['missing'] = False
                            entry['last'] = now
                            if not entry['long'] and now[0] - entry['first'][0] >= 150_000_000:
                                entry['long'] = True
                                self._emit('clock_long', identity=clock,
                                    observed_mono_ns=now[0] - entry['first'][0],
                                    observed_wall_ns=now[1] - entry['first'][1])
                                self._sample(clock, controller, app)
                    for key, entry in self._clocks.items():
                        if key not in live and not entry['missing']:
                            entry['missing'] = True
                            self._emit('clock_not_observed', identity=entry['identity'],
                                last_seen_mono_ns=entry['last'][0], last_seen_wall_ns=entry['last'][1],
                                last_seen_age_ns=entry['last'][0] - entry['first'][0])
                self.stats['max_poll_ns'] = max(self.stats['max_poll_ns'], time.monotonic_ns() - begin)
                self._stop.wait(.01)
        except Exception as error:
            self.stats['gaps'] += 1
            self._emit('observer_error', error_type=type(error).__name__, errno=getattr(error, 'errno', None))
        finally:
            self._emit('observer_finished', stats=self.stats)
