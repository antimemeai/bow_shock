#!/usr/bin/env python3
"""Independent byte/OS oracle for the actual N2a native control executable."""
import errno
import os
from pathlib import Path
import selectors
import signal
import struct
import subprocess
import sys
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]
EXECUTABLE = ROOT/'context/build/native-control/bow-shock-native-control'
WIRE = struct.Struct('>4sBBHQQIBBBB128s')
RUN = b'owned-run-1'
# Fault exit values are16+the closed error enum from the wire contract.
SYNTAX,OP,STATE,SEQ,FENCE,LEASE,TRUNCATED,INIT_EXPIRED,EXPIRED,WRITE_STALL,IO,CLOCK,OVERFLOW,QUEUE = range(1,15)


def frame(op=1, seq=1, fence=0, lease=1000, run=RUN, *, status=0, error=0):
    return WIRE.pack(b'BSCH',1,op,0,seq,fence,lease,len(run),status,error,0,run.ljust(128,b'\0'))


def reply(op, seq, fence=0, *, status=1, run=RUN):
    return frame(op|128,seq,fence,0,run,status=status)


def read_frame(stream, timeout=2):
    output = b''
    deadline = time.monotonic()+timeout
    with selectors.DefaultSelector() as poll:
        poll.register(stream,selectors.EVENT_READ)
        while len(output)<WIRE.size:
            if not poll.select(max(0,deadline-time.monotonic())):
                raise AssertionError(f'no complete control reply; got{len(output)} bytes')
            chunk = os.read(stream.fileno(),WIRE.size-len(output))
            if not chunk:
                raise AssertionError(f'control EOF before reply; got{len(output)} bytes')
            output += chunk
    return output


class Helper(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if sys.platform!='darwin': raise unittest.SkipTest('native helper requires macOS')
        EXECUTABLE.parent.mkdir(parents=True,exist_ok=True)
        subprocess.run(['clang++','-std=c++17','-fobjc-arc','-fobjc-exceptions',
            '-Wall','-Wextra','-Werror','-framework','Foundation',
            '-I',str(ROOT/'native/cef'),'-I',str(ROOT/'native/control'),
            str(ROOT/'native/control/main.mm'),str(ROOT/'native/cef/continuous_clock.mm'),
            '-o',str(EXECUTABLE)],check=True)

    def spawn(self, **options):
        process = subprocess.Popen([str(EXECUTABLE)],stdin=subprocess.PIPE,
            stdout=options.pop('stdout',subprocess.PIPE),stderr=subprocess.PIPE,
            bufsize=0,env={'LANG':'C'},close_fds=True,**options)
        self.addCleanup(self.cleanup,process)
        return process

    def cleanup(self, process):
        # Only this still-owned child can be signalled. Reap once, never afterwards.
        if process.poll() is None:
            os.kill(process.pid,signal.SIGCONT)
            process.terminate()
            try: process.wait(timeout=1)
            except subprocess.TimeoutExpired:
                process.kill();process.wait(timeout=1)
        for stream in [process.stdin,process.stdout,process.stderr]:
            if stream and not stream.closed: stream.close()

    def request(self, process, wire):
        process.stdin.write(wire)
        return read_frame(process.stdout)

    def fault(self, process, code, *, initialized=False, seq=0, fence=0):
        self.assertEqual(process.wait(timeout=2),16+code)
        output = process.stdout.read() if process.stdout else b''
        self.assertEqual(output,frame(255,seq,fence,0,RUN if initialized else b'',status=3,error=code))
        with self.assertRaises(ChildProcessError): os.waitpid(process.pid,os.WNOHANG)

    def test_exact_trace_and_fence_never_reopens(self):
        p=self.spawn()
        self.assertEqual(self.request(p,frame()),reply(1,1))
        self.assertEqual(self.request(p,frame(2,2,0,500)),reply(2,2))
        self.assertEqual(self.request(p,frame(3,3,1,0)),reply(3,3,1,status=2))
        self.assertEqual(self.request(p,frame(2,4,1,500)),reply(2,4,1,status=2))
        self.assertEqual(self.request(p,frame(4,5,2,0)),reply(4,5,2,status=2))
        self.assertEqual(self.request(p,frame(5,6,2,0)),reply(5,6,2,status=3))
        self.assertEqual(p.wait(timeout=2),0)
        self.assertEqual(p.stdout.read(),b'')

    def test_fragmented_actual_pipe_record(self):
        p=self.spawn()
        for byte in frame(): p.stdin.write(bytes([byte]))
        self.assertEqual(read_frame(p.stdout),reply(1,1))
        self.assertEqual(self.request(p,frame(5,2,0,0)),reply(5,2,status=3))
        self.assertEqual(p.wait(timeout=2),0)

    def test_wire_and_unsupported_records_close(self):
        baseline=frame()
        cases=[]
        for offset,value in [(0,0),(4,2),(5,6),(6,1),(29,1),(30,1),(31,1),(159,1)]:
            wire=bytearray(baseline);wire[offset]=value
            cases.append((bytes(wire),OP if offset==5 else SYNTAX))
        cases += [(frame(2,1,0,500),STATE),(frame(seq=2),SEQ),(frame(fence=1),FENCE),
            (frame(lease=0),LEASE),(frame(lease=5001),LEASE),
            (frame(run=b''),SYNTAX),(frame(run=b'bad run'),SYNTAX)]
        for wire,code in cases:
            with self.subTest(code=code,wire=wire[:32]):
                p=self.spawn();p.stdin.write(wire);self.fault(p,code)

    def test_stale_sequence_run_and_fences_close(self):
        cases=[(frame(2,1,0,1000),SEQ),(frame(2,2,1,1000),FENCE),
            (frame(3,2,0,0),FENCE),(frame(1,2,0,1000),STATE),
            (frame(2,2,0,1000,b'other-run'),STATE)]
        for wire,code in cases:
            with self.subTest(code=code):
                p=self.spawn();self.assertEqual(self.request(p,frame()),reply(1,1))
                p.stdin.write(wire);self.fault(p,code,initialized=True,seq=1)

    def test_truncated_record_and_eof(self):
        for length in [0,1,31,159]:
            with self.subTest(length=length):
                p=self.spawn();p.stdin.write(frame()[:length]);p.stdin.close()
                self.fault(p,TRUNCATED if length else IO)
        p=self.spawn();self.assertEqual(self.request(p,frame()),reply(1,1))
        p.stdin.close();self.fault(p,IO,initialized=True,seq=1)

    def test_finite_initialization_and_partial_stall(self):
        for prefix in [b'',frame()[:80]]:
            with self.subTest(prefix=len(prefix)):
                p=self.spawn();start=time.monotonic();p.stdin.write(prefix)
                self.fault(p,INIT_EXPIRED)
                self.assertLess(time.monotonic()-start,1.6)

    def test_continuous_idle_expiry(self):
        p=self.spawn();self.assertEqual(self.request(p,frame(lease=100)),reply(1,1))
        self.fault(p,EXPIRED,initialized=True,seq=1)

    def test_stalled_partial_frame_does_not_extend_lease(self):
        p=self.spawn();self.assertEqual(self.request(p,frame(lease=100)),reply(1,1))
        p.stdin.write(frame(2,2,0,1000)[:80]);self.fault(p,EXPIRED,initialized=True,seq=1)

    def test_paused_helper_expires_before_queued_renewal(self):
        p=self.spawn();self.assertEqual(self.request(p,frame(lease=100)),reply(1,1))
        os.kill(p.pid,signal.SIGSTOP)
        deadline=time.monotonic()+1
        while True:
            state=subprocess.run(['ps','-p',str(p.pid),'-o','stat='],capture_output=True,text=True,check=True).stdout
            if 'T' in state: break
            self.assertLess(time.monotonic(),deadline);time.sleep(.001)
        p.stdin.write(frame(2,2,0,1000))
        time.sleep(.2);os.kill(p.pid,signal.SIGCONT)
        self.fault(p,EXPIRED,initialized=True,seq=1)

    def test_short_owned_pause_preserves_valid_control_lease(self):
        p=self.spawn();self.assertEqual(self.request(p,frame(lease=2000)),reply(1,1))
        os.kill(p.pid,signal.SIGSTOP)
        deadline=time.monotonic()+1
        while True:
            state=subprocess.run(['ps','-p',str(p.pid),'-o','stat='],capture_output=True,text=True,check=True).stdout
            if 'T' in state: break
            self.assertLess(time.monotonic(),deadline);time.sleep(.001)
        p.stdin.write(frame(2,2,0,2000))
        time.sleep(.05);os.kill(p.pid,signal.SIGCONT)
        self.assertEqual(read_frame(p.stdout),reply(2,2))
        self.assertEqual(self.request(p,frame(5,3,0,0)),reply(5,3,status=3))
        self.assertEqual(p.wait(timeout=1),0)

    def full_reply_pipe(self):
        read,write=os.pipe()
        os.set_blocking(write,False)
        filled=0
        while True:
            try: filled+=os.write(write,b'x'*512)
            except BlockingIOError: break
        self.assertGreater(filled,0)
        return read,write,filled

    def test_full_output_pipe_cannot_prevent_continuous_expiry(self):
        read,write,filled=self.full_reply_pipe()
        try:
            p=self.spawn(stdout=write);os.close(write);write=-1
            p.stdin.write(frame(lease=100))
            self.assertEqual(p.wait(timeout=1),16+EXPIRED)
            self.assertEqual(os.read(read,filled+WIRE.size),b'x'*filled)
        finally:
            os.close(read)
            if write>=0: os.close(write)

    def test_stop_progresses_while_output_is_undrained(self):
        read,write,filled=self.full_reply_pipe()
        try:
            p=self.spawn(stdout=write);os.close(write);write=-1
            # Valid initialize/Stop precede a heartbeat bearing the OLD fence.
            # Fence rejection while output stays full proves inbound progress;
            # waiting on the prior reply would hit WriteStall instead.
            p.stdin.write(frame()+frame(3,2,7,0)+frame(2,3,0,1000))
            self.assertEqual(p.wait(timeout=1),16+FENCE)
            self.assertEqual(os.read(read,filled+WIRE.size),b'x'*filled)
        finally:
            os.close(read)
            if write>=0: os.close(write)

    def test_bounded_output_queue_fails_closed(self):
        read,write,_=self.full_reply_pipe()
        try:
            p=self.spawn(stdout=write);os.close(write);write=-1
            p.stdin.write(frame()+frame(2,2,0,1000)+frame(3,3,1,0))
            self.assertEqual(p.wait(timeout=1),16+QUEUE)
        finally:
            os.close(read)
            if write>=0: os.close(write)

    def test_max_width_values_do_not_wrap_or_reopen(self):
        maximum=(1<<64)-1
        p=self.spawn()
        self.assertEqual(self.request(p,frame(lease=5000)),reply(1,1))
        self.assertEqual(self.request(p,frame(3,2,maximum,0)),reply(3,2,maximum,status=2))
        self.assertEqual(self.request(p,frame(2,maximum,maximum,5000)),reply(2,maximum,maximum,status=2))
        p.stdin.write(frame(2,1,maximum,5000))
        self.fault(p,SEQ,initialized=True,seq=maximum,fence=maximum)

    def test_output_stall_and_dead_reader_close_without_sigpipe(self):
        read,write,filled=self.full_reply_pipe()
        try:
            p=self.spawn(stdout=write);os.close(write);write=-1
            start=time.monotonic();p.stdin.write(frame(lease=2000))
            self.assertEqual(p.wait(timeout=1.5),16+WRITE_STALL)
            self.assertLess(time.monotonic()-start,.9)
            self.assertEqual(os.read(read,filled+WIRE.size),b'x'*filled)
        finally:
            os.close(read)
            if write>=0: os.close(write)
        p=self.spawn();p.stdout.close()
        self.assertEqual(p.wait(timeout=1),16+IO)


if __name__=='__main__': unittest.main()
