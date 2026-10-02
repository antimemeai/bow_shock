#!/usr/bin/env python3
"""Actual Foundation connection/process/pipe oracle; macOS only."""
import os
from pathlib import Path
import signal
import shutil
import subprocess
import sys
import tempfile
import time
import tomllib
import unittest

ROOT = Path(__file__).resolve().parents[1]
FIXTURE = r'''
import json, os, signal, sys, time
from pathlib import Path
path=Path(sys.argv[0]).resolve()
path.with_suffix('.pid').write_text(str(os.getpid()))
mode=path.with_suffix('.mode').read_text()
signal.signal(signal.SIGTERM, signal.SIG_IGN)
if mode=='stderr': os.write(2,b'fixture stderr\n')
if mode=='stall':
 time.sleep(30); sys.exit(0)
generation=0
for line in sys.stdin:
 request=json.loads(line)
 op={'initialize':'initialized','ping':'pong','stop_all':'stopped','shutdown':'shutdown'}[request['op']]
 if op=='stopped': generation+=1
 if op=='initialized': run=request['run_id']
 reply={'version':1,'op':op,'run_id':run}
 if 'id' in request: reply['id']=request['id']
 reply.update(stop_generation=generation,active_powers=[])
 data=json.dumps(reply,separators=(',',':'))
 if mode=='boolean': data=data.replace('"version":1','"version":true')
 if mode=='fraction': data=data.replace('"stop_generation":0','"stop_generation":0.5')
 if mode=='duplicate': data=data.replace('"version":1','"version":2,"version":1')
 if mode=='truncated': sys.stdout.write(data); sys.stdout.flush(); sys.exit(0)
 if mode=='oversize': data='x'*65537
 if mode=='trailing': data+='\n{}'
 if mode=='paused_exit': os.kill(os.getppid(),signal.SIGSTOP)
 print(data,flush=True)
 if mode=='paused_exit': sys.exit(0)
 if mode=='idle': time.sleep(.15); sys.exit(0)
 if mode in ('boolean','fraction','duplicate','oversize','trailing'): sys.exit(0)
 if op=='shutdown': sys.exit(0)
'''


class Connection(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if sys.platform != 'darwin': raise unittest.SkipTest('Foundation oracle requires macOS')
        cls.store=tempfile.TemporaryDirectory(prefix='bow-shock-connection-')
        cls.bin=Path(cls.store.name)/'Probe.app/Contents/MacOS'
        cls.bin.mkdir(parents=True)
        (cls.bin.parent/'Info.plist').write_text('''<?xml version="1.0"?><plist version="1.0"><dict><key>CFBundleExecutable</key><string>Probe</string><key>CFBundleIdentifier</key><string>dev.bowshock.connection-test</string></dict></plist>''')
        subprocess.run(['clang++','-std=c++17','-fobjc-arc','-fobjc-exceptions','-Wall','-Wextra','-Werror','-framework','Foundation','-framework','CoreFoundation','-I',str(ROOT/'native/cef'),str(ROOT/'tests/controller_connection_probe.mm'),str(ROOT/'native/cef/controller_connection.mm'),'-o',str(cls.bin/'Probe')],check=True)
        cls.child=cls.bin/'bow-shock-controller'
        cls.child.write_text('#!'+sys.executable+'\n'+FIXTURE)
        cls.child.chmod(0o755)

    @classmethod
    def tearDownClass(cls): cls.store.cleanup()

    def run_case(self, fixture, probe='normal', closed_fd=None):
        reaped=False
        self.child.with_suffix('.mode').write_text(fixture)
        self.child.with_suffix('.pid').unlink(missing_ok=True)
        try:
            process=subprocess.Popen([str(self.bin/'Probe'),probe],stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True,preexec_fn=(lambda:os.close(closed_fd)) if closed_fd is not None else None)
            if fixture=='paused_exit':
                deadline=time.monotonic()+2
                while not self.child.with_suffix('.pid').exists() and time.monotonic()<deadline: time.sleep(.005)
                observed=False
                if self.child.with_suffix('.pid').exists():
                    child_pid=int(self.child.with_suffix('.pid').read_text())
                    while time.monotonic()<deadline:
                        child_state=subprocess.run(['ps','-p',str(child_pid),'-o','stat='],capture_output=True,text=True).stdout.strip()
                        parent_state=subprocess.run(['ps','-p',str(process.pid),'-o','stat='],capture_output=True,text=True).stdout.strip()
                        if child_state.startswith('Z') and parent_state.startswith('T'):
                            observed=True; break
                        time.sleep(.005)
                os.kill(process.pid,signal.SIGCONT)
                if not observed:
                    process.kill(); process.communicate()
                    self.fail('fixture must be observed exited with its owned probe parent stopped')
            try:
                stdout,stderr=process.communicate(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill(); process.communicate(); raise
            result=subprocess.CompletedProcess(process.args,process.returncode,stdout,stderr)
            self.assertEqual(result.returncode,0,result.stderr)
            self.assertIn('HEARTBEAT\n',result.stdout)
            if probe=='join': self.assertIn('JOINED\n',result.stdout)
            else:
                self.assertIn('HEARTBEAT_LATE\n',result.stdout)
                self.assertIn('DONE\n',result.stdout)
            if probe in ('invalidate','join'):
                elapsed=float(next(line.split()[1] for line in result.stdout.splitlines() if line.startswith('INVALIDATED ')))
                self.assertLess(elapsed,.05,'UI invalidation must only publish flags')
            pid=int(next(line.split()[1] for line in result.stdout.splitlines() if line.startswith('CHILD_PID ')))
            with self.assertRaises(ProcessLookupError,msg='owned child must be reaped before probe exits'):
                os.kill(pid,0)
            reaped=True
            return result.stdout
        finally:
            if not reaped and self.child.with_suffix('.pid').exists():
                pid=int(self.child.with_suffix('.pid').read_text())
                command=subprocess.run(['ps','-p',str(pid),'-o','command='],capture_output=True,text=True).stdout
                if str(self.child) in command:
                    try: os.kill(pid,signal.SIGKILL)
                    except ProcessLookupError: pass

    def test_small_live_reply(self): self.assertIn('INIT ok\n',self.run_case('normal'))
    def test_closed_parent_stdin_preserves_child_channel(self):
        self.assertIn('INIT ok\n',self.run_case('normal',closed_fd=0))
    def test_closed_parent_stderr_preserves_child_channel(self):
        self.assertIn('INIT ok\n',self.run_case('stderr',closed_fd=2))
    def test_complete_trace(self):
        output=self.run_case('normal','trace')
        for op in ['INIT','PING','STOP','SHUTDOWN']: self.assertIn(op+' ok\n',output)
    def test_idle_death(self):
        output=self.run_case('idle')
        self.assertIn('INIT ok\n',output)
        self.assertIn('DISCONNECTED\n',output)
    def test_buffered_reply_survives_already_exited_child(self):
        output=self.run_case('paused_exit')
        self.assertIn('INIT ok\n',output)
        self.assertIn('DISCONNECTED\n',output)
    def test_real_rust_controller_canonical_trace(self):
        channel=tomllib.loads((ROOT/'rust-toolchain.toml').read_text())['toolchain']['channel']
        subprocess.run(['cargo','+'+channel,'build','--locked','--release','-p','bow-shock-controller'],cwd=ROOT,check=True)
        original=self.child.read_bytes()
        try:
            shutil.copyfile(ROOT/'target/release/bow-shock-controller',self.child)
            output=self.run_case('real','trace')
            for op in ['INIT','PING','STOP','SHUTDOWN']: self.assertIn(op+' ok\n',output)
        finally:
            self.child.write_bytes(original)
            self.child.chmod(0o755)
    def test_invalidate_does_not_block_ui_and_reaps_term_ignoring_child(self):
        output=self.run_case('stall','invalidate')
        self.assertIn('INVALIDATED ',output)
        self.assertIn('INIT nil\n',output)
    def test_final_join_reaps_before_parent_exit(self):
        self.assertIn('JOINED\n',self.run_case('stall','join'))
    def test_stall_deadline_does_not_block_ui(self):
        output=self.run_case('stall')
        self.assertIn('INIT nil\n',output)
        self.assertIn('DISCONNECTED\n',output)
        self.assertLess(output.index('INIT nil\n'),output.index('HEARTBEAT_LATE\n'))
        self.assertLess(output.index('DISCONNECTED\n'),output.index('HEARTBEAT_LATE\n'))
    def test_malformed_replies(self):
        for mode in ['boolean','fraction','duplicate','truncated','oversize','trailing']:
            with self.subTest(mode=mode):
                output=self.run_case(mode)
                self.assertIn('INIT nil\n',output)
                self.assertNotIn('INIT ok\n',output)


if __name__=='__main__': unittest.main()
