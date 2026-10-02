#!/usr/bin/env python3
"""Actual native reader oracle on owned loopback pages; no model/export."""
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
import signal
import shutil
import time
from pathlib import Path
import subprocess
import tempfile
import threading

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / 'context/build/native/Bow Shock.app/Contents/MacOS/Bow Shock'
SECRET = 'BS_SECRET_MARKER'
HIDDEN = 'BS_HIDDEN_MARKER'
CHILD = 'BS_CHILD_MARKER'


class Page(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/child':
            body = f'<div id="name">{CHILD}</div>'
        elif self.path == '/sensitive':
            body = f'<div id="name">Amber</div><input type="password" value="{SECRET}">'
        else:
            body = f'''<div id="name">Amber</div><div id="price">$12.00</div>
            <div id="hidden" style="display:none">{HIDDEN}</div>
            <div id="echo">{SECRET}</div>
            <iframe src="/child"></iframe>
            <iframe src="http://localhost:{self.server.server_port}/child"></iframe>
            <iframe srcdoc="&lt;div id='name'&gt;{CHILD}&lt;/div&gt;"></iframe>
            <iframe sandbox srcdoc="&lt;div id='name'&gt;{CHILD}&lt;/div&gt;"></iframe>'''
        data = ('<!doctype html><title>Owned observation fixture</title>'+body).encode()
        self.send_response(200)
        self.send_header('Content-Type','text/html; charset=utf-8')
        self.send_header('Content-Length',str(len(data)))
        if self.path=='/opaque-root': self.send_header('Content-Security-Policy','sandbox allow-scripts')
        self.end_headers()
        self.wfile.write(data)

    def log_message(self,*_): pass


def capture(origin, path, pause=False):
    with tempfile.TemporaryDirectory(prefix='bow-shock-reader-') as temporary:
        folder = Path(temporary)
        result = folder/'result.json'
        arguments = [str(APP),f'--bs-profile={folder / "profile"}',
            f'--bs-smoke-output={result}',f'--bs-url={origin}{path}',
            f'--bs-observation-origin={origin}', '--bs-observation-fields=name,price,hidden,echo',
            f'--bs-observation-markers={SECRET}']
        if pause: arguments.append('--bs-observation-pause-start')
        evidence = None
        with (folder/'app.stderr').open('wb') as errors:
            process = subprocess.Popen(arguments,stdout=subprocess.PIPE,stderr=errors)
            failure = None
            try:
                if pause:
                    deadline = time.monotonic()+15
                    while b'BS_OBSERVATION_CAPTURE_STARTED\n' not in (folder/'app.stderr').read_bytes():
                        assert process.poll() is None, 'owned app exited before capture start'
                        assert time.monotonic()<deadline, 'owned app did not begin capture'
                        time.sleep(0.01)
                    # Self-stop precedes dispatch. Observe the exact owned app.
                    while True:
                        state = subprocess.run(['ps','-p',str(process.pid),'-o','stat='],
                            capture_output=True,text=True,check=True).stdout.strip()
                        if 'T' in state: break
                        assert process.poll() is None, 'owned app exited before self-stop'
                        assert time.monotonic()<deadline, 'owned app did not self-stop'
                        time.sleep(0.01)
                    time.sleep(3.4)
                    os.kill(process.pid,signal.SIGCONT)
                deadline = time.monotonic()+40
                try:
                    process.communicate(timeout=8)
                except subprocess.TimeoutExpired:
                    evidence = ROOT/'context/runtime/native-observation-diagnostics'/str(process.pid)
                    evidence.mkdir(parents=True,exist_ok=True)
                    alive = process.poll() is None
                    metadata = {'pid':process.pid,'path':path,'pause':pause,
                        'after_seconds':8,'owned_parent_alive':alive,'returncode':process.returncode}
                    (evidence/'process.json').write_text(json.dumps(metadata,indent=2)+'\n')
                    # No concurrent wait/reap runs during this exact-PID sample.
                    if alive:
                        sampled = subprocess.run(['sample',str(process.pid),'1','-file',str(evidence/'app.sample.txt')],
                            capture_output=True,timeout=10)
                        (evidence/'sample.stderr').write_bytes(sampled.stderr)
                    process.communicate(timeout=max(0.1,deadline-time.monotonic()))
            except BaseException as error:
                failure = error
            finally:
                if pause and process.poll() is None: os.kill(process.pid,signal.SIGCONT)
                if process.poll() is None:
                    process.terminate()
                    try: process.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        process.kill();process.wait(timeout=5)
                if process.stdout: process.stdout.close()
        stderr = (folder/'app.stderr').read_bytes()
        if failure:
            if evidence is None:
                evidence = ROOT/'context/runtime/native-observation-diagnostics'/str(process.pid)
                evidence.mkdir(parents=True,exist_ok=True)
            shutil.copytree(folder,evidence/'owned-fixture',dirs_exist_ok=True)
            (evidence/'failure.txt').write_text(repr(failure)+'\n')
        diagnostic=ROOT/'context/runtime/native-observation-app.stderr'
        diagnostic.parent.mkdir(parents=True,exist_ok=True)
        with diagnostic.open('ab') as log:
            log.write(f'CASE {path} pause={pause} pid={process.pid} evidence={evidence}\n'.encode()+stderr)
        if failure: raise failure
        assert process.returncode == 0, stderr.decode(errors='replace')[-4000:]
        smoke = json.loads(result.read_text())
        assert 'observation' in smoke, 'native shell has no projected observation record'
        return smoke['observation']


def main():
    assert APP.is_file(), 'build native app before reader smoke'
    (ROOT/'context/runtime/native-observation-app.stderr').write_bytes(b'')
    server = ThreadingHTTPServer(('127.0.0.1',0),Page)
    threading.Thread(target=server.serve_forever,daemon=True).start()
    origin = f'http://127.0.0.1:{server.server_port}'
    try:
        public = capture(origin,'/public')
        encoded = json.dumps(public)
        assert all(marker not in encoded for marker in [SECRET,HIDDEN,CHILD]), encoded
        assert public['status']=='partial' and public['fixture_only'] is True, public
        assert public['general_observation_enabled'] is False,public
        ref = public['observation_ref']
        assert ref['origin']['security_origin']==origin, ref
        assert ref['origin']['provenance']=='Runtime.executionContextCreated.defaultContext', ref
        for key in ['run_id','surface_id','frame_id','document_id','capture_id']:
            assert isinstance(ref[key],str) and ref[key], ref
        for key in ['attachment_generation','activation_generation','node_generation']:
            assert isinstance(ref[key],int) and ref[key]>=1, ref
        assert ref['capture_start_continuous_ns']<=ref['capture_end_continuous_ns'],ref
        fields = {field['field_id']:field for field in public['fields']}
        assert set(fields)=={'name','price','hidden','echo'},fields
        assert fields['name']['text']=='Amber' and fields['price']['text']=='$12.00',fields
        assert fields['name']['backend_node_id']>0, fields
        assert fields['hidden']['status']=='withheld' and fields['echo']['status']=='withheld',fields
        assert public['coverage']['child_frames']=='withheld',public
        assert public['coverage']['cef_frame_count']>=5,public
        sensitive = capture(origin,'/sensitive')
        assert sensitive['status']=='withheld' and not sensitive['fields'],sensitive
        assert SECRET not in json.dumps(sensitive),sensitive
        opaque = capture(origin,'/opaque-root')
        assert opaque['status']=='failed' and not opaque['fields'],opaque
        assert opaque['reason']=='effective_origin_or_document_unverified',opaque
        late = capture(origin,'/public',pause=True)
        assert late['status']=='failed' and not late['fields'],late
        assert late['reason']=='host_timeout_native_work_not_cancelled',late
        print(json.dumps({'native_observation_smoke':'pass','fields':fields,'coverage':public['coverage']},indent=2))
    finally:
        server.shutdown();server.server_close()


if __name__=='__main__': main()
