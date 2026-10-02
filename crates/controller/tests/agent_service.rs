#![cfg(target_os = "macos")]
//! Actual controlled child transport and independent zero-SQL-effects oracle.
use serde_json::{Value, json};
use std::{
    io::{BufRead, BufReader, Write},
    path::{Path, PathBuf},
    process::{Child, ChildStdin, Command, Stdio},
    sync::{
        Arc, Mutex, MutexGuard,
        atomic::{AtomicBool, Ordering},
        mpsc,
    },
    time::{Duration, Instant},
};
const PEER: &str = r#"#!/usr/bin/python3
import json,os,signal,socket,sys,time
from pathlib import Path
if sys.argv[1:]==['--version']:
 print('codex-cli 0.160.0',flush=True);sys.exit(0)
base=Path(sys.argv[0]).parent;mode=(base/'mode').read_text()
assert os.get_blocking(0) and os.get_blocking(1)
if mode=='writer_stall':
 s=socket.socket(fileno=0);s.setsockopt(socket.SOL_SOCKET,socket.SO_RCVBUF,1024);s.detach()
with (base/'pids').open('a') as f:f.write(str(os.getpid())+'\n')
assert sys.argv[1:4]==['app-server','--stdio','--strict-config']
def emit(v):print(json.dumps(v,separators=(',',':')),flush=True)
thread='thread-'+str(os.getpid());turn='turn-'+str(os.getpid())
for line in sys.stdin:
 r=json.loads(line);m=r['method']
 if m=='initialized':continue
 if m=='initialize':v={'userAgent':'fixture','platformFamily':'unix','platformOs':'macos','codexHome':os.environ['CODEX_HOME']}
 elif m=='account/read':v={'requiresOpenaiAuth':True,'account':{'type':'chatgpt','email':None,'planType':'pro'}}
 elif m=='account/rateLimits/read':v={'accountId':'changed-account' if mode=='account_mismatch' else 'fixture-account','rateLimits':{}}
 elif m=='thread/start':
  p=r['params'];assert p['model']=='fixture-model' and p['sandbox']=='read-only' and p['ephemeral'] is True
  v={'model':'fixture-model','modelProvider':'openai','cwd':str(base),'approvalPolicy':'never','approvalsReviewer':'user','sandbox':{'type':'readOnly'},'thread':{'id':thread,'ephemeral':True,'cliVersion':'0.160.0','turns':[]}}
  if mode=='effective_mismatch':v['approvalPolicy']='on-request'
  if mode=='account_change':emit({'method':'account/updated','params':{'authMode':'chatgpt','planType':'pro'}})
  if mode=='before':
   (base/'before').write_text(str(os.getpid()))
   while not (base/'release').exists():time.sleep(.005)
 elif m=='turn/start':
  assert r['params']['threadId']==thread
  prompt=json.loads(r['params']['input'][0]['text']);(base/'export').write_text(json.dumps(prompt))
  if mode=='stall':signal.signal(signal.SIGTERM,signal.SIG_IGN);time.sleep(20);sys.exit(0)
  if mode=='late':time.sleep(6)
  final={'request_id':prompt['request_id'],'candidate_ids':['r0f0'],'no_match':False,'explanation':'existing source only'}
  if mode=='foreign':final['candidate_ids']=['r0f1']
  if mode=='invented':final['value']='invented'
  if mode=='no_match':final.update(candidate_ids=[],no_match=True)
  if mode=='select_both':final['candidate_ids']=['r0f0','r0f1']
  text=json.dumps(final,separators=(',',':'))
  if mode=='duplicate_key':text=text[:-1]+',"no_match":true}'
  item={'type':'agentMessage','id':'final-1','text':text,'phase':'final_answer' if mode=='competing' else None}
  if mode=='phase_bool':item['phase']=True
  events=[{'method':'item/completed','params':{'threadId':thread,'turnId':turn,'completedAtMs':1,'item':item}}]
  if mode=='competing':events.append({'method':'item/completed','params':{'threadId':thread,'turnId':turn,'completedAtMs':2,'item':dict(item,id='final-2',phase='final_answer')}});item=dict(item,id='final-2',phase='final_answer')
  if mode=='conflicting':item=dict(item,text='{}')
  if mode=='callback':events=[{'id':5,'method':'item/commandExecution/requestApproval','params':{'threadId':thread,'turnId':turn}}]
  events.append({'method':'turn/completed','params':{'threadId':thread,'turn':{'id':turn,'status':'completed','error':None,'items':[item],'itemsView':'summary'}}})
  if mode=='empty_summary':events[-1]['params']['turn']['items']=[]
  if mode=='not_loaded':events[-1]['params']['turn'].update(items=[],itemsView='notLoaded')
  if mode=='missing_error':del events[-1]['params']['turn']['error']
  if mode=='early':
   for event in events:emit(event)
  emit({'id':r['id'],'result':{'turn':{'id':turn,'status':'inProgress','items':[]}}})
  if mode!='early':
   for event in events:emit(event)
  continue
 else:raise AssertionError(m)
 emit({'id':r['id'],'result':v})
 if mode=='writer_stall' and m=='thread/start':
  prefix=os.read(0,512);(base/'prefix').write_bytes(prefix)
  (base/'writer_boundary').write_text(str(os.getpid()))
  time.sleep(20);sys.exit(0)
 if mode=='dead' and m=='thread/start':sys.exit(0)
"#;

// These are one-host transport oracles, not simultaneous-host startup load tests.
// Concurrent fixture clang/process launches exhibited pre-main dyld stalls; retain
// that availability evidence separately rather than weakening response deadlines.
static OWNED_HOST: Mutex<()> = Mutex::new(());

struct Client {
    _owned_host: MutexGuard<'static, ()>,
    child: Child,
    input: ChildStdin,
    replies: mpsc::Receiver<Value>,
    next: u64,
    dir: PathBuf,
    last_op: String,
    close_reader: Arc<AtomicBool>,
    pause_reader: Arc<AtomicBool>,
    reader_paused: Arc<AtomicBool>,
    reader_closed: Arc<AtomicBool>,
}
impl Client {
    fn open(name: &str) -> Self {
        let owned_host = OWNED_HOST
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner());
        let root = Path::new(env!("CARGO_MANIFEST_DIR")).join("../..");
        let dir = std::env::temp_dir().join(format!("bow-agent-{}-{name}", std::process::id()));
        let _ = std::fs::remove_dir_all(&dir);
        std::fs::create_dir_all(&dir).unwrap();
        let probe = dir.join("clock");
        assert!(
            Command::new("clang++")
                .args([
                    "-std=c++17",
                    "-Wall",
                    "-Wextra",
                    "-Werror",
                    "-fobjc-arc",
                    "-framework",
                    "Foundation",
                    "-I"
                ])
                .arg(root.join("native/cef"))
                .arg(root.join("native/cef/continuous_clock.mm"))
                .arg(root.join("tests/agent_clock_probe.mm"))
                .arg("-o")
                .arg(&probe)
                .status()
                .unwrap()
                .success()
        );
        assert!(Command::new(&probe).output().unwrap().status.success());
        let peer = dir.join("peer");
        std::fs::write(&peer, PEER).unwrap();
        std::fs::write(dir.join("mode"), "positive").unwrap();
        use std::os::unix::fs::PermissionsExt;
        std::fs::set_permissions(&peer, std::fs::Permissions::from_mode(0o700)).unwrap();
        let mut child = Command::new(env!("CARGO_BIN_EXE_bow-shock-controller"))
            .arg("--table-db")
            .arg(dir.join("tables.sqlite"))
            .arg("--clock-probe")
            .arg(&probe)
            .args([
                "--owned-origin",
                "https://fixture.test",
                "--agent-executable",
            ])
            .arg(peer)
            .arg("--agent-cwd")
            .arg(&dir)
            .arg("--agent-user-home")
            .arg(&dir)
            .arg("--agent-home")
            .arg(&dir)
            .args([
                "--agent-model",
                "fixture-model",
                "--agent-provider",
                "openai",
                "--agent-account",
                "fixture-account",
            ])
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .stderr(Stdio::inherit())
            .spawn()
            .unwrap();
        let input = child.stdin.take().unwrap();
        let output = child.stdout.take().unwrap();
        let (tx, replies) = mpsc::sync_channel(16);
        let close_reader = Arc::new(AtomicBool::new(false));
        let pause_reader = Arc::new(AtomicBool::new(false));
        let reader_paused = Arc::new(AtomicBool::new(false));
        let reader_closed = Arc::new(AtomicBool::new(false));
        let closing = close_reader.clone();
        let paused = pause_reader.clone();
        let parked = reader_paused.clone();
        let closed = reader_closed.clone();
        std::thread::spawn(move || {
            {
                let mut reader = BufReader::new(output);
                loop {
                    let mut line = String::new();
                    if reader.read_line(&mut line).unwrap_or(0) == 0
                        || closing.load(Ordering::SeqCst)
                    {
                        break;
                    }
                    while paused.load(Ordering::SeqCst) && !closing.load(Ordering::SeqCst) {
                        parked.store(true, Ordering::SeqCst);
                        std::thread::sleep(Duration::from_millis(1));
                    }
                    parked.store(false, Ordering::SeqCst);
                    if closing.load(Ordering::SeqCst) {
                        break;
                    }
                    assert!(line.len() <= 65537);
                    if tx.send(serde_json::from_str(&line).unwrap()).is_err() {
                        break;
                    }
                }
            }
            closed.store(true, Ordering::SeqCst);
        });
        Self {
            _owned_host: owned_host,
            child,
            input,
            replies,
            next: 1,
            dir,
            last_op: "initialize".into(),
            close_reader,
            pause_reader,
            reader_paused,
            reader_closed,
        }
    }
    fn send(&mut self, value: Value) {
        writeln!(self.input, "{value}").unwrap();
        self.input.flush().unwrap();
    }
    fn receive(&self) -> Value {
        match self.replies.recv_timeout(Duration::from_secs(5)) {
            Ok(reply) => reply,
            Err(error) => {
                eprintln!(
                    "actual owned controller PID {} phase {} receive failure {error:?}",
                    self.child.id(),
                    self.last_op
                );
                let report = Path::new(env!("CARGO_MANIFEST_DIR"))
                    .join("../../context/review-controller-table")
                    .join(format!("agent-timeout-{}.sample", self.child.id()));
                let _ = Command::new("/usr/bin/sample")
                    .arg(self.child.id().to_string())
                    .args(["1", "1", "-file"])
                    .arg(report)
                    .output();
                panic!("actual controller response unavailable in {}", self.last_op);
            }
        }
    }
    fn call(&mut self, op: &str, mut fields: Value) -> Value {
        let id = self.queue(op, fields.take());
        let reply = self.receive();
        assert_eq!(reply["id"], id);
        reply
    }
    fn queue(&mut self, op: &str, mut fields: Value) -> u64 {
        self.last_op = op.into();
        let id = self.next;
        self.next += 1;
        fields["op"] = op.into();
        fields["version"] = 1.into();
        fields["id"] = id.into();
        self.send(fields);
        id
    }
    fn ready(&mut self) {
        self.send(json!({"version":1,"op":"initialize","run_id":"agent-owned-run"}));
        assert_eq!(self.receive()["op"], "initialized");
        let until = Instant::now() + Duration::from_secs(10);
        loop {
            let status = self.call("table_status", json!({"commit_id":null}));
            if status["health"] == "ready" {
                break;
            }
            assert!(Instant::now() < until);
        }
        assert_eq!(
            self.call("table_scope", json!({"origin":"https://fixture.test"}))["op"],
            "table_scoped"
        );
        loop {
            let status = self.call("agent_metadata", json!({}));
            if status["state"] == "ready" {
                break;
            }
            assert_ne!(status["state"], "unavailable", "{status}");
            assert!(Instant::now() < until);
            std::thread::sleep(Duration::from_millis(10));
        }
    }
    fn review(&mut self) -> Value {
        self.review_values("SELECTED_MARKER", "EXCLUDED_MARKER")
    }
    fn review_values(&mut self, first: &str, second: &str) -> Value {
        let sample: Value = serde_json::from_slice(
            &Command::new(self.dir.join("clock"))
                .output()
                .unwrap()
                .stdout,
        )
        .unwrap();
        let observation = json!({"run_id":"agent-owned-run","surface_id":"owned","frame_id":"root","document_id":"doc","capture_id":"capture","security_origin":"https://fixture.test","attachment_generation":1,"activation_generation":1,"node_generation":1,"capture_start_ns":sample["continuous_ns"],"capture_end_ns":sample["continuous_ns"]});
        let fields:Vec<_>=[("name",first),("secret",second)].iter().enumerate().map(|(i,(name,value))|json!({"name":name,"state":{"kind":"value","source":value,"value":value},"source":{"observation":observation,"node_id":i+1,"fragment":value,"visibility":"layout-present-occlusion-unknown","normalization":"identity"}})).collect();
        let stage=self.call("table_stage",json!({"batch":{"schema_version":"catalog-v1","pattern_version":"literal-v1","partial":true,"rows":[{"fields":fields}]}}));
        assert_eq!(stage["op"], "table_staged");
        self.call(
            "table_review",
            json!({"staging_id":stage["staging_id"],"retention_ms":30000}),
        )["review"]
            .clone()
    }
    fn start(&mut self, review: Value) -> String {
        self.start_ttl(review, 10000)
    }
    fn start_ttl(&mut self, review: Value, ttl: u64) -> String {
        let started=self.call("agent_start",json!({"review":review,"candidate_ids":["r0f0"],"objective":"select the name","ttl_ms":ttl}));
        assert_eq!(started["op"], "agent_started", "{started}");
        started["task_id"].as_str().unwrap().to_owned()
    }
    fn final_status(&mut self, task: &str) -> Value {
        let until = Instant::now() + Duration::from_secs(8);
        loop {
            let status = self.call("agent_status", json!({"task_id":task}));
            if status["state"] != "running" {
                return status;
            }
            assert!(Instant::now() < until, "{status}");
            std::thread::sleep(Duration::from_millis(10));
        }
    }
    fn clean_close(&mut self) {
        assert_eq!(self.call("table_close", json!({}))["op"], "table_closed");
        assert_eq!(self.call("shutdown", json!({}))["op"], "shutdown");
        assert!(self.child.wait().unwrap().success());
        let db = rusqlite::Connection::open(self.dir.join("tables.sqlite")).unwrap();
        assert_eq!(
            db.query_row("select count(*) from rows", [], |r| r.get::<_, i64>(0))
                .unwrap(),
            0
        );
        if let Ok(pids) = std::fs::read_to_string(self.dir.join("pids")) {
            for pid in pids.lines() {
                assert!(
                    !Command::new("/bin/kill")
                        .args(["-0", pid])
                        .stdout(Stdio::null())
                        .stderr(Stdio::null())
                        .status()
                        .unwrap()
                        .success(),
                    "owned provider still present: {pid}"
                );
            }
        }
    }
}
impl Drop for Client {
    fn drop(&mut self) {
        self.close_reader.store(true, Ordering::SeqCst);
        self.pause_reader.store(false, Ordering::SeqCst);
        let _ = self.child.kill();
        let _ = self.child.wait();
        if let Ok(pids) = std::fs::read_to_string(self.dir.join("pids")) {
            for pid in pids.lines() {
                let command = Command::new("/bin/ps")
                    .args(["-p", pid, "-o", "command="])
                    .output()
                    .unwrap();
                if String::from_utf8_lossy(&command.stdout)
                    .contains(self.dir.join("peer").to_str().unwrap())
                {
                    let _ = Command::new("/bin/kill").args(["-KILL", pid]).status();
                }
            }
        }
        let _ = std::fs::remove_dir_all(&self.dir);
    }
}

#[test]
fn cached_agent_metadata_never_waits_for_provider() {
    let mut c = Client::open("metadata");
    c.send(json!({"version":1,"op":"initialize","run_id":"agent-owned-run"}));
    assert_eq!(c.receive()["op"], "initialized");
    let start = Instant::now();
    let result = c.call("agent_metadata", json!({}));
    assert_eq!(result["op"], "agent_metadata");
    assert!(start.elapsed() < Duration::from_secs(1));
    assert!(matches!(
        result["state"].as_str(),
        Some("opening" | "ready" | "unavailable")
    ));
    let db = rusqlite::Connection::open(c.dir.join("tables.sqlite")).unwrap();
    let tables: i64 = db
        .query_row(
            "select count(*) from sqlite_master where name='rows'",
            [],
            |r| r.get(0),
        )
        .unwrap();
    if tables > 0 {
        assert_eq!(
            db.query_row("select count(*) from rows", [], |r| r.get::<_, i64>(0))
                .unwrap(),
            0
        );
    }
    drop(db);
    let until = Instant::now() + Duration::from_secs(10);
    loop {
        if c.call("table_status", json!({"commit_id":null}))["health"] == "ready" {
            break;
        }
        assert!(Instant::now() < until);
    }
    c.clean_close();
}

#[test]
fn grounded_selected_fields_and_early_notifications_have_zero_sql_effect() {
    for mode in ["positive", "early", "no_match", "not_loaded"] {
        let mut c = Client::open(mode);
        std::fs::write(c.dir.join("mode"), mode).unwrap();
        c.ready();
        let review = c.review();
        let task = c.start(review);
        let status = c.final_status(&task);
        assert_eq!(
            status["state"],
            if mode == "no_match" {
                "no_match"
            } else {
                "candidate"
            },
            "{status}"
        );
        let export = std::fs::read_to_string(c.dir.join("export")).unwrap();
        assert!(export.contains("SELECTED_MARKER"));
        assert!(!export.contains("EXCLUDED_MARKER"));
        if mode != "no_match" {
            assert_eq!(
                status["proposal"]["batch"]["rows"][0]["fields"]
                    .as_array()
                    .unwrap()
                    .len(),
                1
            );
            assert_eq!(
                status["proposal"]["batch"]["rows"][0]["fields"][0]["state"]["value"],
                "SELECTED_MARKER"
            );
        }
        c.clean_close();
    }
}
#[test]
fn malformed_ungrounded_or_direction_confused_finals_never_become_rows() {
    for mode in [
        "foreign",
        "invented",
        "duplicate_key",
        "conflicting",
        "competing",
        "callback",
        "dead",
        "phase_bool",
        "missing_error",
        "empty_summary",
    ] {
        let mut c = Client::open(mode);
        std::fs::write(c.dir.join("mode"), mode).unwrap();
        c.ready();
        let review = c.review();
        let task = c.start(review);
        let status = c.final_status(&task);
        assert_eq!(status["state"], "failed", "{status}");
        assert!(status["proposal"].is_null());
        c.clean_close();
    }
}

#[test]
fn stop_before_export_discards_projection_and_new_child_cannot_flush_it() {
    let mut c = Client::open("before-stop");
    std::fs::write(c.dir.join("mode"), "before").unwrap();
    c.ready();
    let review = c.review();
    let task = c.start(review.clone());
    let until = Instant::now() + Duration::from_secs(5);
    while !c.dir.join("before").exists() {
        assert!(Instant::now() < until);
        std::thread::sleep(Duration::from_millis(5));
    }
    let old = std::fs::read_to_string(c.dir.join("before")).unwrap();
    let now = Instant::now();
    assert_eq!(c.call("stop_all", json!({}))["op"], "stopped");
    assert!(now.elapsed() < Duration::from_secs(1));
    assert_eq!(c.final_status(&task)["state"], "canceled");
    assert!(!c.dir.join("export").exists());
    std::fs::write(c.dir.join("release"), "").unwrap();
    let until = Instant::now() + Duration::from_secs(2);
    while Command::new("/bin/kill")
        .args(["-0", old.trim()])
        .stderr(Stdio::null())
        .status()
        .unwrap()
        .success()
    {
        assert!(Instant::now() < until, "old owned child still present");
        std::thread::sleep(Duration::from_millis(5));
    }
    std::fs::write(c.dir.join("mode"), "positive").unwrap();
    let next = c.start(review);
    let final_ = c.final_status(&next);
    assert_eq!(final_["state"], "candidate");
    assert_eq!(
        final_["proposal"]["batch"]["rows"][0]["fields"][0]["state"]["value"],
        "SELECTED_MARKER"
    );
    let exported: Value =
        serde_json::from_slice(&std::fs::read(c.dir.join("export")).unwrap()).unwrap();
    assert_eq!(exported["request_id"], next);
    assert_ne!(exported["request_id"], task);
    c.clean_close();
}

#[test]
fn delayed_actual_clock_result_cannot_authorize_first_export_byte() {
    let mut c = Client::open("delayed-clock");
    std::fs::write(c.dir.join("mode"), "before").unwrap();
    c.ready();
    let review = c.review();
    let task = c.start(review);
    let until = Instant::now() + Duration::from_secs(5);
    while !c.dir.join("before").exists() {
        assert!(
            Instant::now() < until,
            "fresh peer must reach pre-export boundary"
        );
        std::thread::sleep(Duration::from_millis(5));
    }
    // The owned probe samples actual continuous time and then delays its result.
    // No clock value is invented or advanced by the fixture.
    std::fs::write(c.dir.join("clock.delay"), "").unwrap();
    std::fs::write(c.dir.join("release"), "").unwrap();
    let status = c.final_status(&task);
    assert_eq!(status["state"], "failed", "{status}");
    assert_eq!(status["export_disposition"], "not_transmitted");
    assert!(!c.dir.join("export").exists());
    std::fs::remove_file(c.dir.join("clock.delay")).unwrap();
    c.clean_close();
}

#[test]
fn cancellation_after_handoff_is_not_recall_and_reaps_stalled_child() {
    let mut c = Client::open("after-stop");
    std::fs::write(c.dir.join("mode"), "stall").unwrap();
    c.ready();
    let review = c.review();
    let task = c.start(review);
    let until = Instant::now() + Duration::from_secs(5);
    while !c.dir.join("export").exists() {
        assert!(Instant::now() < until);
        std::thread::sleep(Duration::from_millis(5));
    }
    assert_eq!(
        c.call("agent_cancel", json!({"task_id":task}))["op"],
        "agent_canceled"
    );
    let status = c.final_status(&task);
    assert_eq!(status["state"], "canceled");
    assert_eq!(status["export_disposition"], "provider_retained_unknown");
    assert!(status["proposal"].is_null());
    c.clean_close();
}

#[test]
fn actual_continuous_deadline_retires_late_output() {
    let mut c = Client::open("late");
    std::fs::write(c.dir.join("mode"), "late").unwrap();
    c.ready();
    let review = c.review();
    let task = c.start_ttl(review, 5000);
    let until = Instant::now() + Duration::from_secs(4);
    while !c.dir.join("export").exists() {
        assert!(
            Instant::now() < until,
            "must reach actual exported turn before expiry, not fail during setup"
        );
        std::thread::sleep(Duration::from_millis(5));
    }
    let status = c.final_status(&task);
    assert_eq!(status["state"], "expired");
    assert!(status["proposal"].is_null());
    assert!(status["publication_guard"].is_null());
    c.clean_close();
}

#[test]
fn approved_or_changed_review_cannot_authorize_export() {
    let mut c = Client::open("review-fence");
    c.ready();
    let review = c.review();
    let mut altered = review.clone();
    altered["version"] = 2.into();
    assert_eq!(
        c.call(
            "agent_start",
            json!({"review":altered,"candidate_ids":["r0f0"],"objective":"select","ttl_ms":10000})
        )["op"],
        "agent_error"
    );
    assert_eq!(
        c.call("table_approve", json!({"review":review}))["op"],
        "table_approved"
    );
    let reply = c.call(
        "agent_start",
        json!({"review":review,"candidate_ids":["r0f0"],"objective":"select","ttl_ms":10000}),
    );
    assert_eq!(reply["code"], "agent_rejected");
    assert!(!c.dir.join("export").exists());
    c.clean_close();
}

#[test]
fn changed_destination_or_effective_policy_prevents_observation_handoff() {
    for mode in ["account_mismatch", "account_change", "effective_mismatch"] {
        let mut c = Client::open(mode);
        c.ready();
        let review = c.review();
        // Initial metadata is valid; only the fresh request destination changes.
        std::fs::write(c.dir.join("mode"), mode).unwrap();
        let task = c.start(review);
        let status = c.final_status(&task);
        assert_eq!(status["state"], "failed", "{status}");
        assert_eq!(status["export_disposition"], "not_transmitted");
        assert!(!c.dir.join("export").exists());
        c.clean_close();
    }
}

#[test]
fn stop_remains_responsive_during_actual_partial_private_writer_stall() {
    let mut c = Client::open("writer-stall");
    c.ready();
    let literal = format!("SELECTED_{}", "x".repeat(1950));
    let review = c.review_values(&literal, &literal);
    std::fs::write(c.dir.join("mode"), "writer_stall").unwrap();
    let started = c.call("agent_start", json!({"review":review,"candidate_ids":["r0f0","r0f1"],"objective":"select existing fields","ttl_ms":10000}));
    assert_eq!(started["op"], "agent_started", "{started}");
    let task = started["task_id"].as_str().unwrap();
    let until = Instant::now() + Duration::from_secs(4);
    while !c.dir.join("writer_boundary").exists() {
        assert!(
            Instant::now() < until,
            "peer must read actual turn prefix before writer fault oracle"
        );
        std::thread::sleep(Duration::from_millis(5));
    }
    let prefix = std::fs::read(c.dir.join("prefix")).unwrap();
    assert!(!prefix.is_empty() && !prefix.contains(&b'\n'));
    let status = c.call("agent_status", json!({"task_id":task}));
    assert_eq!(
        status["export_disposition"], "partially_transmitted",
        "must saturate actual private socket, not stall after full handoff: {status}"
    );
    assert_eq!(
        status["state"], "running",
        "Stop must interrupt a still-active stalled writer"
    );
    let before = Instant::now();
    assert_eq!(c.call("stop_all", json!({}))["op"], "stopped");
    assert!(before.elapsed() < Duration::from_secs(1));
    let retired = c.final_status(task);
    assert_eq!(retired["state"], "canceled");
    assert_eq!(retired["export_disposition"], "partially_transmitted");
    assert!(!c.dir.join("export").exists());
    c.clean_close();
}

#[test]
fn terminal_host_stdout_loss_reaps_active_provider_before_process_exit() {
    let mut c = Client::open("stdout-loss");
    c.ready();
    std::fs::write(c.dir.join("mode"), "stall").unwrap();
    let review = c.review();
    let task = c.start(review);
    let until = Instant::now() + Duration::from_secs(5);
    while !c.dir.join("export").exists() {
        assert!(Instant::now() < until);
        std::thread::sleep(Duration::from_millis(5));
    }
    assert_eq!(
        c.call("agent_status", json!({"task_id":task}))["state"],
        "running"
    );
    c.close_reader.store(true, Ordering::SeqCst);
    c.send(json!({"version":1,"op":"ping","id":c.next}));
    c.next += 1;
    let until = Instant::now() + Duration::from_secs(2);
    while !c.reader_closed.load(Ordering::SeqCst) {
        assert!(
            Instant::now() < until,
            "actual host stdout reader must close"
        );
        std::thread::sleep(Duration::from_millis(5));
    }
    // This write now reaches a controller whose output pipe has no reader.
    writeln!(c.input, "{}", json!({"version":1,"op":"ping","id":c.next})).unwrap();
    c.input.flush().unwrap();
    let until = Instant::now() + Duration::from_secs(5);
    let exit = loop {
        if let Some(exit) = c.child.try_wait().unwrap() {
            break exit;
        }
        assert!(
            Instant::now() < until,
            "terminal host must reconcile owned provider before exit"
        );
        std::thread::sleep(Duration::from_millis(5));
    };
    assert!(!exit.success());
    let db = rusqlite::Connection::open(c.dir.join("tables.sqlite")).unwrap();
    assert_eq!(
        db.query_row("select count(*) from rows", [], |r| r.get::<_, i64>(0))
            .unwrap(),
        0
    );
    for pid in std::fs::read_to_string(c.dir.join("pids")).unwrap().lines() {
        assert!(
            !Command::new("/bin/kill")
                .args(["-0", pid])
                .stderr(Stdio::null())
                .status()
                .unwrap()
                .success(),
            "owned provider not reaped: {pid}"
        );
    }
}

#[test]
fn queued_status_preserves_original_task_under_actual_stdout_backpressure() {
    let mut c = Client::open("status-correlation");
    c.ready();
    let literal = format!("SELECTED_{}", "x".repeat(1950));
    let review = c.review_values(&literal, &literal);
    std::fs::write(c.dir.join("mode"), "select_both").unwrap();
    let start = json!({"review":review,"candidate_ids":["r0f0","r0f1"],"objective":"select existing fields","ttl_ms":10000});
    let a = c.call("agent_start", start.clone());
    assert_eq!(a["op"], "agent_started");
    let a = a["task_id"].as_str().unwrap();
    assert_eq!(c.final_status(a)["state"], "candidate");
    // Reader holds at most one decoded record; six large guarded replies fill
    // the real stdout pipe and leave captured publication work pending.
    c.pause_reader.store(true, Ordering::SeqCst);
    // Wake the blocking reader with a small lifecycle reply before large
    // statuses exist; its parked acknowledgement excludes read-ahead capacity.
    let wake = c.queue("ping", json!({}));
    let until = Instant::now() + Duration::from_secs(1);
    while !c.reader_paused.load(Ordering::SeqCst) {
        assert!(
            Instant::now() < until,
            "stdout reader must actually park before saturation"
        );
        std::thread::sleep(Duration::from_millis(1));
    }
    let ids: Vec<_> = (0..6)
        .map(|_| c.queue("agent_status", json!({"task_id":a})))
        .collect();
    std::thread::sleep(Duration::from_millis(50));
    let cancel = c.queue("agent_cancel", json!({"task_id":a}));
    let new = c.queue("agent_start", start);
    let b = format!("agent-{new}");
    let until = Instant::now() + Duration::from_millis(1100);
    loop {
        let exported = std::fs::read(c.dir.join("export"))
            .ok()
            .and_then(|bytes| serde_json::from_slice::<Value>(&bytes).ok());
        if exported.is_some_and(|value| value["request_id"] == b) {
            break;
        }
        assert!(
            Instant::now() < until,
            "replacement must progress while actual stdout blocked, before2s IO watchdog"
        );
        std::thread::sleep(Duration::from_millis(5));
    }
    c.pause_reader.store(false, Ordering::SeqCst);
    let mut retired = 0;
    for _ in 0..9 {
        let reply = c.receive();
        let id = reply["id"].as_u64().unwrap();
        if ids.contains(&id) {
            assert_ne!(reply["task_id"], b, "queued A request cannot adopt B");
            if reply["op"] == "agent_error" {
                assert_eq!(reply["code"], "unknown_task");
                retired += 1;
            } else {
                assert_eq!(reply["task_id"], a);
            }
        } else {
            assert!(id == cancel || id == new || id == wake);
        }
    }
    assert!(
        retired > 0,
        "must reach delayed captured-task publication boundary"
    );
    c.clean_close();
}
