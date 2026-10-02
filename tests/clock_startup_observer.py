#!/usr/bin/env python3
"""Actual libproc observer scope; no shipping clock or sampler warm-up."""
import json
import ctypes
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import threading
import time
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'scripts'))
from clock_startup_observer import ClockStartupObserver, ProcReader

PEER = '''import pathlib,subprocess,sys,time
base=pathlib.Path(sys.argv[2]);role=sys.argv[1]
if role=='clock':
 (base/'clock.pid').write_text(str(__import__('os').getpid()));time.sleep(1.5)
elif role=='controller':
 p=subprocess.Popen([sys.executable,__file__,'clock',str(base)])
 (base/'controller.pid').write_text(str(__import__('os').getpid()))
 p.wait()
else:
 p=subprocess.Popen([sys.executable,__file__,'controller',str(base)])
 other=subprocess.Popen(['/bin/sleep','1.5']);p.wait();other.wait()
'''


class ObserverOracle(unittest.TestCase):
    def test_matched_sdk_reads_current_pid_parent_and_birth(self):
        reader = ProcReader()
        current = reader.identity(os.getpid())
        self.assertIsNotNone(current)
        self.assertEqual(current['pid'], os.getpid())
        self.assertEqual(current['ppid'], os.getppid())
        self.assertEqual(current['uid'], os.getuid())
        self.assertGreater(current['birth_us'], 0)
        self.assertLessEqual(current['birth_us'] * 1000, time.time_ns())
        self.assertTrue(Path(current['path']).is_absolute())
        task = reader.task(os.getpid())
        self.assertIsNotNone(task)
        self.assertGreater(task['resident_bytes'], 0)
        self.assertGreater(task['threads'], 0)

    def observe(self, wrong_controller=False):
        with tempfile.TemporaryDirectory(prefix='bow-clock-observer-') as temporary:
            base = Path(temporary)
            peer = base / 'peer.py'
            peer.write_text(PEER)
            executable = Path(ProcReader().identity(os.getpid())['path'])
            observer = ClockStartupObserver(executable,
                Path('/bin/sleep') if wrong_controller else executable,
                executable, base / 'artifacts', sample_limit=0)
            with subprocess.Popen([sys.executable, str(peer), 'app', str(base)],
                    stdout=subprocess.DEVNULL, stderr=subprocess.PIPE) as app:
                buffer = (ctypes.c_int * 256)()
                count = observer.reader.lib.proc_listchildpids(os.getpid(), buffer, ctypes.sizeof(buffer))
                self.assertEqual(count, 1, 'actual wrapper result is PID count, not byte count')
                self.assertEqual(buffer[0], app.pid)
                observer.start(app.pid)
                try:
                    self.assertEqual(app.wait(timeout=6), 0)
                finally:
                    observer.stop()
            events = [json.loads(line) for line in observer.timeline_path.read_text().splitlines()]
            self.assertFalse(any(event['event'] == 'observer_error' for event in events), events)
            clocks = [event for event in events if event['event'] == 'clock_seen']
            if wrong_controller:
                self.assertEqual(clocks, [])
            else:
                self.assertEqual(len(clocks), 1, events)
                self.assertEqual(clocks[0]['identity']['pid'], int((base / 'clock.pid').read_text()))
                self.assertEqual(clocks[0]['identity']['ppid'], int((base / 'controller.pid').read_text()))
                self.assertTrue(any(event['event'] == 'clock_long' for event in events))
                self.assertFalse(any(event['event'] == 'sample_started' for event in events))
            summary = json.loads(observer.summary_path.read_text())
            self.assertGreater(summary['polls'], 0)
            self.assertFalse(summary['thread_alive'])

    def test_only_exact_owned_three_level_chain_is_clock(self):
        self.observe()

    def test_wrong_controller_path_withholds_descendant(self):
        self.observe(wrong_controller=True)

    def test_sampler_launch_stall_does_not_stall_discovery_and_owned_tool_reaps(self):
        with tempfile.TemporaryDirectory(prefix='bow-clock-sampler-') as temporary:
            base = Path(temporary)
            peer = base / 'peer.py'
            peer.write_text(PEER)
            executable = Path(ProcReader().identity(os.getpid())['path'])
            observer = ClockStartupObserver(executable, executable, executable,
                base / 'artifacts', sample_limit=1)
            entered, release = threading.Event(), threading.Event()
            original = subprocess.Popen

            def delayed_launch(arguments, **options):
                if arguments[0] == '/usr/bin/sample':
                    entered.set()
                    self.assertTrue(release.wait(timeout=2))
                return original(arguments, **options)

            with mock.patch.object(subprocess, 'Popen', delayed_launch):
                with subprocess.Popen([sys.executable, str(peer), 'app', str(base)],
                        stdout=subprocess.DEVNULL, stderr=subprocess.PIPE) as app:
                    observer.start(app.pid)
                    try:
                        self.assertTrue(entered.wait(timeout=2), 'must reach sampler launch')
                        polls = observer.stats['polls']
                        time.sleep(.3)
                        self.assertGreaterEqual(observer.stats['polls'] - polls, 10)
                        release.set()
                        until = time.monotonic() + 2
                        while not any(json.loads(line)['event'] == 'sample_launch_returned'
                                for line in observer.timeline_path.read_text().splitlines()):
                            self.assertLess(time.monotonic(), until)
                            time.sleep(.01)
                    finally:
                        release.set()
                        observer.stop()
                    self.assertEqual(app.wait(timeout=6), 0)
            events = [json.loads(line) for line in observer.timeline_path.read_text().splitlines()]
            launch = next(event for event in events if event['event'] == 'sample_launch_returned')
            self.assertGreaterEqual(launch['launch_mono_ns'], 300_000_000)
            self.assertIsNone(ProcReader().identity(launch['sampler_pid']), 'owned sampler must be reaped')
            self.assertTrue(any(event['event'] == 'sample_finished' for event in events))
            summary = json.loads(observer.summary_path.read_text())
            self.assertFalse(summary['thread_alive'])
            self.assertFalse(summary['sampler_thread_alive'])


if __name__ == '__main__':
    unittest.main()
