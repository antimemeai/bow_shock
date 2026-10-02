#!/usr/bin/env python3
"""Actual closed Foundation table class with owned private OS process/pipe peer."""
from pathlib import Path
import json
import fcntl
import os
import signal
import subprocess
import sys
import tempfile
import unittest
import sqlite3
import time
import tomllib

ROOT = Path(__file__).resolve().parents[1]
CONTENT = '{"note":"café 😀   quote \\\" + slash /","retention_ms":1000}'
PEER = r'''
import json, os, signal, subprocess, sys, time
from pathlib import Path
path=Path(sys.argv[0]);mode=path.with_suffix('.mode').read_text();path.with_suffix('.pid').write_text(str(os.getpid()))
assert len(sys.argv)==7 and sys.argv[1]=='--table-db' and sys.argv[3]=='--clock-probe' and sys.argv[5:]==['--owned-origin','https://fixture.test']
signal.signal(signal.SIGTERM,signal.SIG_IGN)
content=path.with_suffix('.content').read_text();generation=0;run=None
path.with_suffix('.signals').write_text(str(signal.getsignal(signal.SIGCHLD)))
extra=path.with_suffix('.extra-fd')
try:os.fstat(int(extra.read_text()) if extra.exists() else 200);path.with_suffix('.extra').write_text('leaked')
except OSError:pass
if mode=='stall':time.sleep(20);sys.exit(0)
def emit(out,boot=False):
 data=json.dumps(out,separators=(',',':'),sort_keys=not boot,ensure_ascii=False)
 if mode=='boolean':data=data.replace('"version":1','"version":true')
 if mode=='fraction':data=data.replace('"stop_generation":0','"stop_generation":0.5')
 if mode=='duplicate':data=data.replace('"version":1','"version":2,"version":1')
 if mode=='unknown':data=data[:-1]+',"extra":false}'
 if mode=='truncated':sys.stdout.write(data);sys.stdout.flush();sys.exit(0)
 if mode=='oversize':data='x'*65537
 if mode=='fragmented':
  for offset in range(0,len(data),3):os.write(1,data[offset:offset+3].encode());time.sleep(.0001)
  os.write(1,b'\n')
 else:print(data,flush=True)
 if mode in ('boolean','fraction','duplicate','unknown','oversize'):sys.exit(0)
def base(req,op):return dict(version=1,op=op,run_id=run,id=req['id'],stop_generation=generation)
for line in sys.stdin:
 r=json.loads(line);op=r['op']
 with path.with_suffix('.requests').open('a') as receipt:receipt.write(op+'\n')
 if mode=='paused' and op=='initialize':os.kill(os.getppid(),signal.SIGSTOP)
 if op=='initialize':run=r['run_id']
 if op in ('initialize','ping','stop_all','shutdown'):
  if op=='stop_all':generation+=1
  out=dict(version=1,op={'initialize':'initialized','ping':'pong','stop_all':'stopped','shutdown':'shutdown'}[op],run_id=run)
  if 'id' in r:out['id']=r['id']
  out.update(stop_generation=generation,active_powers=[]);emit(out,True)
  if op=='shutdown':sys.exit(0)
  if mode=='idle':time.sleep(.1);sys.exit(0)
 elif op=='table_review':
  witness=json.loads(subprocess.check_output([sys.argv[4]]))
  guard=dict(boot_id=witness['boot_id'],valid_until_ns=witness['continuous_ns']+(150000000 if mode=='stale' else 800000000 if mode=='busy_ui' else 10000000000))
  out=base(r,'table_reviewed');out.update(review=dict(staging_id='stage-1',version=1,content=content),publication_guard=guard)
  if mode=='parallel':
   urgent=json.loads(next(sys.stdin));assert urgent['op']=='stop_all' and urgent['id']>r['id'];generation+=1
   ack=dict(version=1,op='stopped',run_id=run,id=urgent['id'],stop_generation=generation,active_powers=[]);emit(ack,True)
   emit(out)
  else:
   if mode=='busy_ui':time.sleep(.25)
   if mode=='stale':time.sleep(.25)
   emit(out)
 elif op=='table_approve':
  assert set(r)=={'op','version','id','review'} and r['review']['content']==content
  out=base(r,'table_approved');out['approval_id']='approval-1';emit(out)
 elif op=='table_close':emit(base(r,'table_closed'))
 else:raise AssertionError(op)
'''
class TableConnection(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if sys.platform!='darwin':raise unittest.SkipTest('actual Foundation/macOS process oracle')
        cls.store=tempfile.TemporaryDirectory(prefix='bow-table-connection-');cls.path=Path(cls.store.name);cls.executable=cls.path/'Probe'
        subprocess.run(['clang++','-std=c++17','-fobjc-arc','-fobjc-exceptions','-Wall','-Wextra','-Werror','-DBS_TABLE_CONNECTION_TEST','-framework','Foundation','-framework','CoreFoundation','-I',str(ROOT/'native/cef'),str(ROOT/'tests/table_connection_probe.mm'),str(ROOT/'native/cef/table_connection.mm'),str(ROOT/'native/cef/continuous_clock.mm'),'-o',str(cls.executable)],check=True)
        cls.peer=cls.path/'peer';cls.peer.write_text('#!'+sys.executable+'\n'+PEER);cls.peer.chmod(0o700);cls.peer.with_suffix('.content').write_text(CONTENT)
    @classmethod
    def tearDownClass(cls):cls.store.cleanup()
    def run_case(self,peer='normal',parent='normal',closed_fd=None,extra_fd=None):
        self.peer.with_suffix('.mode').write_text(peer)
        for suffix in ('.pid','.requests','.extra','.signals'):self.peer.with_suffix(suffix).unlink(missing_ok=True)
        process=subprocess.Popen([str(self.executable),str(self.peer),str(self.path/'tables.sqlite'),str(ROOT/'context/build/native/bow_shock_clock_probe'),parent],stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True,pass_fds=(extra_fd,) if extra_fd is not None else (),preexec_fn=(lambda:os.close(closed_fd)) if closed_fd is not None else None)
        if parent=='pause':
            deadline=time.monotonic()+10
            while time.monotonic()<deadline:
                state=subprocess.run(['ps','-p',str(process.pid),'-o','stat='],capture_output=True,text=True).stdout.strip()
                if state.startswith('T'):break
                time.sleep(.005)
            else:process.kill();process.communicate();self.fail('must observe exact owned parent stopped')
            time.sleep(2.2);os.kill(process.pid,signal.SIGCONT)
        try:
            stdout,stderr=process.communicate(timeout=6)
        except subprocess.TimeoutExpired as error:
            subprocess.run(["sample",str(process.pid),"1","1","-file",str(ROOT/"context/review-controller-table"/f"native-timeout-{peer}-{parent}-{closed_fd}.sample")],capture_output=True,timeout=4)
            process.kill()
            marker=self.peer.with_suffix('.pid')
            if marker.exists():
                pid=int(marker.read_text());command=subprocess.run(['ps','-p',str(pid),'-o','command='],capture_output=True,text=True).stdout
                if str(self.peer) in command:
                    try:os.kill(pid,signal.SIGKILL)
                    except ProcessLookupError:pass
            stdout,stderr=process.communicate(timeout=3)
            (ROOT/'context/review-controller-table'/f'native-timeout-{peer}-{parent}-{closed_fd}.log').write_text(stdout+stderr)
            raise AssertionError(f'owned parent timeout: {error}; {stdout}; {stderr}')
        result=subprocess.CompletedProcess(process.args,process.returncode,stdout,stderr)
        if peer!='stall' and parent!='pause':self.assertIn('initialize',self.peer.with_suffix('.requests').read_text())
        self.assertEqual(result.returncode,0,result.stdout+result.stderr);self.assertIn('HEARTBEAT\n',result.stdout);self.assertIn('JOINED\n',result.stdout)
        child=int(next(line.split()[1] for line in result.stdout.split('\n') if line.startswith('CHILD_PID ')));
        if parent=='pause':
            self.assertEqual(child,-1);self.assertFalse(self.peer.with_suffix('.requests').exists())
        else:
            self.assertGreater(child,0)
            with self.assertRaises(ProcessLookupError):os.kill(child,0)
        replies=[json.loads(line[7:]) for line in result.stdout.split('\n') if line.startswith('RESULT ')]
        return result.stdout,replies
    def test_live_small_bootstrap(self):
        out,_=self.run_case();self.assertIn('INIT initialized\n',out);self.assertIn('PING pong\n',out)
    def test_fragmented_reply(self):self.assertIn('PING pong\n',self.run_case('fragmented')[0])
    def test_closed_inherited_stdio(self):
        for fd in (0,2):self.assertIn('PING pong\n',self.run_case(closed_fd=fd)[0])
    def test_exact_review_approve_and_terminal_ack(self):
        out,replies=self.run_case(parent='review');self.assertIn('SHUTDOWN shutdown\n',out)
        review=next(r for r in replies if r['op']=='table_reviewed');self.assertEqual(review['review']['content'],CONTENT)
        self.assertIn('APPROVE table_approved\n',out);self.assertIn('CLOSE table_closed\n',out)
    def test_urgent_stop_while_table_waits_and_bounded_slots(self):
        out,replies=self.run_case('parallel','parallel');self.assertIn('STOP stopped\n',out)
        reviewed=next(r for r in replies if r.get('request_op')=='table_review' and r['op']=='native_table_withheld');self.assertEqual(reviewed['reason'],'stopped');self.assertNotIn('review',reviewed)
        self.assertEqual([r['reason'] for r in replies if r.get('request_op') in ('table_read','stop_all') and r['op']=='native_table_withheld'],['busy','busy'])
    def test_expired_native_guard(self):
        out,replies=self.run_case('stale','stale');self.assertNotIn('REVIEW table_reviewed\n',out)
        self.assertTrue(any(r.get('reason')=='stale_guard' for r in replies))
    def test_guard_expires_during_busy_ui(self):
        out,replies=self.run_case('busy_ui','busy_ui');self.assertIn('UI_RESUMED\n',out)
        self.assertNotIn('REVIEW table_reviewed\n',out);self.assertTrue(any(r.get('reason')=='stale_guard' for r in replies))
    def test_idle_child_death_clears_worker_connection(self):
        out,_=self.run_case('idle');self.assertIn('CONNECTED 0\n',out);self.assertIn('DISCONNECTED\n',out)
    def test_stall_deadline_before_manual_invalidation(self):
        out,_=self.run_case('stall');self.assertLess(out.index('DISCONNECTED\n'),out.index('HEARTBEAT_LATE\n'))
    def test_malformed_closed_replies(self):
        for mode in ('boolean','fraction','duplicate','unknown','truncated','oversize'):
            with self.subTest(mode=mode):
                out,replies=self.run_case(mode);self.assertNotIn('INIT initialized\n',out);self.assertTrue(all(r['op']=='native_table_withheld' for r in replies))
    def test_actual_parent_pause_expires_before_child_spawn(self):
        out,replies=self.run_case(parent='pause');self.assertNotIn('INIT initialized\n',out)
        self.assertTrue(all(r['op']=='native_table_withheld' for r in replies))
    def test_child_default_sigchld(self):
        self.run_case(parent='sigchld');self.assertEqual(self.peer.with_suffix('.signals').read_text(),'0')
    def test_private_child_does_not_inherit_unrelated_descriptor(self):
        original=os.open('/dev/null',os.O_RDONLY)
        extra=fcntl.fcntl(original,fcntl.F_DUPFD_CLOEXEC,200);os.close(original)
        self.peer.with_suffix('.extra-fd').write_text(str(extra))
        try:
            self.run_case(extra_fd=extra);self.assertFalse(self.peer.with_suffix('.extra').exists())
        finally:
            os.close(extra);self.peer.with_suffix('.extra-fd').unlink()
    def test_actual_rust_child_sqlite_and_clean_reopen(self):
        channel=tomllib.loads((ROOT/'rust-toolchain.toml').read_text())['toolchain']['channel']
        subprocess.run(['cargo','+'+channel,'build','--locked','--bin','bow-shock-controller','--target-dir',str(self.path/'rust-target')],cwd=ROOT,check=True,stdout=subprocess.DEVNULL)
        executable=self.path/'rust-target/debug/bow-shock-controller'
        clock=ROOT/'context/build/native/bow_shock_clock_probe'
        self.assertGreater(json.loads(subprocess.check_output([str(clock)]))['continuous_ns'],0)
        saved=None
        for mode in ('rust','reopen'):
            result=subprocess.run([str(self.executable),str(executable),str(self.path/'real.sqlite'),str(clock),mode],capture_output=True,text=True,timeout=10)
            self.assertEqual(result.returncode,0,result.stdout+result.stderr);self.assertIn('SHUTDOWN shutdown\n',result.stdout)
            child=int(next(line.split()[1] for line in result.stdout.split('\n') if line.startswith('CHILD_PID ')))
            self.assertGreater(child,0)
            with self.assertRaises(ProcessLookupError):os.kill(child,0)
            replies=[json.loads(line[7:]) for line in result.stdout.split('\n') if line.startswith('RESULT ')]
            read=next(r for r in replies if r['op']=='table_read')
            self.assertEqual(read['batch']['rows'][0]['fields'][0]['state']['value'],'native-owned-marker')
            with sqlite3.connect(self.path/'real.sqlite') as db:
                rows=db.execute('select payload from rows').fetchall();self.assertEqual(len(rows),1)
                self.assertEqual(json.loads(rows[0][0]),read['batch']['rows'][0])
                record=db.execute('select review,boot_id,expires_ns from commits').fetchone()
                self.assertEqual(db.execute('select dirty from meta').fetchone(),(0,))
            self.assertEqual(record[1],read['publication_guard']['boot_id']);self.assertEqual(record[2],read['publication_guard']['valid_until_ns'])
            if mode=='rust':
                reviewed=next(r for r in replies if r['op']=='table_reviewed');self.assertEqual(record[0],reviewed['review']['content']);saved=record
            else:self.assertEqual(record,saved)
if __name__=='__main__':unittest.main()
