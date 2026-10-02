#!/usr/bin/env python3
"""Actual Foundation parent connection and concrete control helper; no CEF."""
import os
from pathlib import Path
import subprocess
import signal
import selectors
import sys
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]


class Connection(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if sys.platform != 'darwin': raise unittest.SkipTest('macOS native only')
        cls.store = tempfile.TemporaryDirectory(prefix='bow-shock-control-link-')
        cls.bin = Path(cls.store.name)
        cls.probe = cls.bin/'probe'
        flags = ['clang++','-std=c++20','-fobjc-arc','-fobjc-exceptions',
                 '-Wall','-Wextra','-Werror','-framework','Foundation','-framework','CoreFoundation',
                 '-I',str(ROOT/'native/cef'),'-I',str(ROOT/'native/control')]
        subprocess.run(flags+[str(ROOT/'tests/control_connection_probe.mm'),
            str(ROOT/'native/cef/control_connection.mm'),str(ROOT/'native/cef/continuous_clock.mm'),
            '-o',str(cls.probe)],check=True)
        cls.helper = cls.bin/'control-helper'
        subprocess.run(flags+[str(ROOT/'native/control/main.mm'),
            str(ROOT/'native/cef/continuous_clock.mm'),'-o',str(cls.helper)],check=True)
        cls.fixture = cls.bin/'fault-helper'
        subprocess.run(['clang++','-std=c++20','-Wall','-Wextra','-Werror',
            str(ROOT/'tests/control_connection_fault_peer.cc'),'-o',str(cls.fixture)],check=True)
        cls.inheritance = cls.bin/'inheritance-helper'
        subprocess.run(['clang++','-std=c++20','-Wall','-Wextra','-Werror',
            str(ROOT/'tests/control_connection_inheritance.cc'),'-o',str(cls.inheritance)],check=True)

    @classmethod
    def tearDownClass(cls): cls.store.cleanup()

    def run_case(self, mode='normal', fault=None, closed_fd=None):
        child = self.helper
        if fault=='inheritance': child = self.inheritance
        elif fault:
            child = self.fixture; child.with_suffix('.mode').write_text(fault)
            for extension in ['.pid','.ready','.seen','.sent','.release']:
                child.with_suffix(extension).unlink(missing_ok=True)
        p = subprocess.Popen([str(self.probe),str(child),mode],stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,text=True,close_fds=True,
            preexec_fn=(lambda:os.close(closed_fd)) if closed_fd is not None else None)
        prefix = ''
        try:
            if mode=='pause_self':
                with selectors.DefaultSelector() as ready:
                    ready.register(p.stdout,selectors.EVENT_READ)
                    self.assertTrue(ready.select(2),'owned app did not initialize before its stop')
                    prefix = p.stdout.readline()
                self.assertIn('INIT ok PID ',prefix)
                helper_pid = int(prefix.split(' PID ')[1])
                deadline = time.monotonic()+1.5
                observed = False
                while time.monotonic()<deadline:
                    app_state = subprocess.run(['ps','-p',str(p.pid),'-o','stat='],capture_output=True,text=True).stdout.strip()
                    child_state = subprocess.run(['ps','-p',str(helper_pid),'-o','stat='],capture_output=True,text=True).stdout.strip()
                    if app_state.startswith('T') and child_state.startswith('Z'):
                        observed = True;break
                    time.sleep(.005)
                os.kill(p.pid,signal.SIGCONT)
                self.assertTrue(observed,'actual helper must expire while only its parent is stopped')
            out,err = p.communicate(timeout=5)
            out = prefix+out
        except subprocess.TimeoutExpired as failure:
            evidence = ROOT/'context/runtime'/f'control-connection-failure-{p.pid}'
            evidence.mkdir(parents=True,exist_ok=True)
            (evidence/'stdout').write_bytes(failure.stdout or b'')
            (evidence/'stderr').write_bytes(failure.stderr or b'')
            if p.poll() is None:
                sample = subprocess.run(['sample',str(p.pid),'1','1'],capture_output=True,text=True,timeout=5)
                (evidence/'sample.txt').write_text(sample.stdout+sample.stderr)
                p.kill()
            final_out,final_err = p.communicate(timeout=2)
            (evidence/'stdout-final').write_text(prefix+final_out)
            (evidence/'stderr-final').write_text(final_err)
            (evidence/'case').write_text(f'mode={mode} fault={fault} closed_fd={closed_fd} return={p.returncode}\n')
            self.fail(f'owned process timed out; evidence {evidence}')
        # Preserve the direct process output before assertions in this method or
        # its caller, including an early nil ACK that still exits/reaps normally.
        evidence = ROOT/'context/runtime/control-connection-cases'/str(p.pid)
        evidence.mkdir(parents=True,exist_ok=True)
        (evidence/'stdout').write_text(out)
        (evidence/'stderr').write_text(err)
        (evidence/'case').write_text(f'mode={mode} fault={fault} closed_fd={closed_fd} return={p.returncode}\n')
        self.assertEqual(p.returncode,0,err)
        self.assertNotIn('GUARD',out)
        self.assertIn('REAPED\n',out)
        pids = [int(line.split(' PID ')[1]) for line in out.splitlines() if ' PID ' in line]
        for pid in pids:
            if pid > 0:
                with self.assertRaises(ProcessLookupError): os.kill(pid,0)
        if fault and fault!='inheritance':
            self.assertTrue(child.with_suffix('.ready').exists(),'native peer never reached configured ready phase')
            if fault!='stall':
                self.assertEqual(child.with_suffix('.seen').read_text(),'request')
                self.assertEqual(child.with_suffix('.sent').read_text(),
                    {'partial':'159','eof':'eof','flood':'flood'}.get(fault,'160'))
        return out

    def test_real_helper_heartbeat_and_exact_fence(self):
        out = self.run_case()
        self.assertIn('INIT ok',out)
        self.assertIn('LIVE 1\n',out)
        self.assertIn('WORKER_FENCE 7 LIVE 1\n',out)
        self.assertIn('FENCE ok 7\n',out)
        self.assertIn('STALE nil\n',out)
        self.assertIn('AUTHORITY_LOST LIVE 0',out)

    def test_real_worker_progresses_while_main_stalled(self):
        out = self.run_case('stall_main')
        self.assertIn('INIT ok',out)
        self.assertLess(out.index('MAIN_STALLED'),out.index('WORKER_FENCE 7 LIVE 1'))
        self.assertLess(out.index('REAPED'),out.index('MAIN_RESUMED'))
        self.assertIn('FENCE nil',out,'late callback must not publish success after authority loss')
        self.assertIn('BUSY nil',out)
        self.assertIn('BACKLOG nil',out,'accepted callback slot must remain bounded while UI is stalled')

    def test_delayed_start_callback_withholds_after_authority_loss(self):
        out = self.run_case('late_main')
        self.assertIn('INIT nil PID ',out)
        self.assertNotIn('INIT ok',out)
        self.assertIn('REASON authority_lost',out)

    def test_constructor_launch_budget(self):
        out = self.run_case('delay_start')
        self.assertIn('INIT nil PID -1',out)
        self.assertNotIn('INIT ok',out)
        self.assertIn('INIT_REASON launch_deadline',out)

    def test_malformed_partial_stalled_and_eof(self):
        for fault in ['capability','fence','partial','stall','eof','flood']:
            with self.subTest(fault=fault):
                out = self.run_case('fault',fault)
                self.assertIn('INIT nil',out)
                self.assertNotIn('INIT ok',out)
                expected = {'capability':'noncanonical_reply','fence':'noncanonical_reply',
                    'partial':'initialization_deadline','stall':'initialization_deadline',
                    'eof':'reply_eof','flood':'unexpected_reply'}[fault]
                self.assertIn('REASON '+expected,out)

    def test_idle_child_exit(self):
        out = self.run_case('fault','idle')
        self.assertIn('INIT ok',out)
        self.assertIn('DISCONNECTED',out)
        self.assertIn('AUTHORITY_LOST LIVE 0',out)
        self.assertIn('CHILD_EXIT 0',out,'native idle peer must exit normally after positive UI release')

    def test_closed_parent_stdio_preserves_channel(self):
        for fd in [0,2]:
            with self.subTest(fd=fd):
                self.assertIn('WORKER_FENCE 7 LIVE 1',self.run_case(closed_fd=fd))

    def test_private_pipe_inheritance_and_minimal_environment(self):
        out = self.run_case('normal','inheritance')
        self.assertIn('WORKER_FENCE 7 LIVE 1',out)

    def test_bad_constructor_identity_or_path_does_not_launch(self):
        for mode in ['bad_run','bad_url']:
            with self.subTest(mode=mode):
                self.assertIn('INIT nil PID -1',self.run_case(mode))

    def test_parent_suspension_leaves_helper_independent_lease(self):
        out = self.run_case('pause_self')
        self.assertIn('AUTHORITY_LOST LIVE 0',out)

    def test_invalidate_is_ui_flag_only_and_reaps_term_ignoring_child(self):
        out = self.run_case('invalidate','stall')
        elapsed = float(next(line.split()[1] for line in out.splitlines() if line.startswith('INVALIDATE_SECONDS')))
        self.assertGreaterEqual(elapsed,0)
        self.assertLess(elapsed,.05)
        self.assertIn('INIT nil',out)
        self.assertNotIn('READY_MISSING',out)
        self.assertIn('CHILD_EXIT 137 REASON invalidated',out)


if __name__ == '__main__': unittest.main()
