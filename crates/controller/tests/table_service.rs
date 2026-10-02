#![cfg(target_os = "macos")]

use rusqlite::Connection;
use serde_json::{Value, json};
use std::{
    io::{BufRead, BufReader, Write},
    path::{Path, PathBuf},
    process::{Child, ChildStdin, Command, Stdio},
    sync::{OnceLock, mpsc},
    thread,
    time::{Duration, Instant},
};

fn probe() -> &'static Path {
    static PROBE: OnceLock<PathBuf> = OnceLock::new();
    PROBE
        .get_or_init(|| {
            let root = Path::new(env!("CARGO_MANIFEST_DIR")).join("../..");
            let out = std::env::temp_dir()
                .join(format!("bow-shock-service-clock-{}", std::process::id()));
            assert!(
                Command::new("clang++")
                    .args(["-std=c++17", "-fobjc-arc", "-framework", "Foundation", "-I"])
                    .arg(root.join("native/cef"))
                    .arg(root.join("native/cef/continuous_clock.mm"))
                    .arg(root.join("tests/native_clock_probe.mm"))
                    .arg("-o")
                    .arg(&out)
                    .status()
                    .unwrap()
                    .success()
            );
            // Verify the freshly compiled SDK producer before giving it to the
            // service's deliberately short availability supervisor. Initial
            // executable availability is test setup, not a cached clock sample.
            let first = Command::new(&out).output().unwrap();
            assert!(first.status.success());
            let _: bow_shock_evidence::ClockWitness =
                serde_json::from_slice(&first.stdout).unwrap();
            out
        })
        .as_path()
}
struct Client {
    child: Child,
    input: ChildStdin,
    permit: mpsc::SyncSender<()>,
    replies: mpsc::Receiver<Value>,
    next: u64,
    dir: PathBuf,
}
impl Client {
    fn open(dir: PathBuf, run: &str) -> Self {
        std::fs::create_dir_all(&dir).unwrap();
        let mut child = Command::new(env!("CARGO_BIN_EXE_bow-shock-controller"))
            .args(["--table-db"])
            .arg(dir.join("tables.sqlite"))
            .arg("--clock-probe")
            .arg(probe())
            .args(["--owned-origin", "https://fixture.test"])
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .stderr(Stdio::inherit())
            .spawn()
            .unwrap();
        let input = child.stdin.take().unwrap();
        let output = child.stdout.take().unwrap();
        let (permit, permits) = mpsc::sync_channel(1);
        let (reply, replies) = mpsc::sync_channel(1);
        thread::spawn(move || {
            let mut reader = BufReader::new(output);
            while permits.recv().is_ok() {
                let mut line = String::new();
                if reader.read_line(&mut line).unwrap_or(0) == 0 {
                    break;
                }
                assert!(line.len() <= 65_537);
                if reply.send(serde_json::from_str(&line).unwrap()).is_err() {
                    break;
                }
            }
        });
        let mut c = Self {
            child,
            input,
            permit,
            replies,
            next: 1,
            dir,
        };
        c.send(json!({"op":"initialize", "version":1,"run_id":run}));
        assert_eq!(c.receive()["op"], "initialized");
        let deadline = Instant::now() + Duration::from_secs(5);
        loop {
            let r = c.call("table_status", json!({"commit_id":null}));
            if r["health"] == "ready" {
                break;
            }
            assert!(Instant::now() < deadline, "not ready: {r}");
        }
        assert_eq!(
            c.call("table_scope", json!({"origin":"https://fixture.test"}))["op"],
            "table_scoped"
        );
        c
    }
    fn send(&mut self, v: Value) {
        writeln!(self.input, "{v}").unwrap();
        self.input.flush().unwrap();
    }
    fn request(&mut self, op: &str, mut fields: Value) -> u64 {
        let id = self.next;
        self.next += 1;
        fields["op"] = op.into();
        fields["version"] = 1.into();
        fields["id"] = id.into();
        self.send(fields);
        id
    }
    fn receive(&self) -> Value {
        self.permit.send(()).unwrap();
        self.replies
            .recv_timeout(Duration::from_secs(5))
            .expect("service reply deadline")
    }
    fn call(&mut self, op: &str, fields: Value) -> Value {
        let id = self.request(op, fields);
        let reply = self.receive();
        assert_eq!(reply["id"], id);
        reply
    }
    fn stage(&mut self, run: &str, large: bool) -> String {
        let r = self.call("table_stage", json!({"batch":batch(run, large)}));
        assert_eq!(r["op"], "table_staged", "{r}");
        r["staging_id"].as_str().unwrap().into()
    }
    fn save(&mut self, run: &str, retention: u64) -> (String, Value) {
        let stage = self.stage(run, false);
        let reviewed = self.call(
            "table_review",
            json!({"staging_id":stage,"retention_ms":retention}),
        );
        let review = reviewed["review"].clone();
        let approved = self.call("table_approve", json!({"review":review}));
        assert_eq!(approved["op"], "table_approved", "{approved}");
        let again = self.call("table_approve", json!({"review":review}));
        assert_eq!(again["approval_id"], approved["approval_id"]);
        let committed = self.call(
            "table_commit",
            json!({"approval_id":approved["approval_id"]}),
        );
        let id = committed["commit_id"].as_str().unwrap().to_string();
        let duplicate = self.call(
            "table_commit",
            json!({"approval_id":approved["approval_id"]}),
        );
        assert_eq!(duplicate["commit_id"], id);
        let end = Instant::now() + Duration::from_secs(5);
        loop {
            let status = self.call("table_status", json!({"commit_id":id}));
            if status["state"] == "committed" {
                break;
            }
            assert!(Instant::now() < end, "did not commit: {status}");
        }
        (id, review)
    }
    fn db(&self) -> Connection {
        Connection::open(self.dir.join("tables.sqlite")).unwrap()
    }
    fn finish(mut self) {
        assert_eq!(self.call("table_close", json!({}))["op"], "table_closed");
        assert_eq!(self.call("shutdown", json!({}))["op"], "shutdown");
        let end = Instant::now() + Duration::from_secs(5);
        while self.child.try_wait().unwrap().is_none() {
            assert!(Instant::now() < end);
            thread::sleep(Duration::from_millis(5));
        }
        assert!(self.child.wait().unwrap().success());
    }
}
impl Drop for Client {
    fn drop(&mut self) {
        let _ = self.child.kill();
        let _ = self.child.wait();
    }
}
fn directory(name: &str) -> PathBuf {
    let p = std::env::temp_dir().join(format!(
        "bow-shock-controller-{name}-{}",
        std::process::id()
    ));
    let _ = std::fs::remove_dir_all(&p);
    p
}
fn batch(run: &str, large: bool) -> Value {
    static CAPTURE: OnceLock<u64> = OnceLock::new();
    let capture = *CAPTURE.get_or_init(|| {
        let out = Command::new(probe()).output().unwrap();
        serde_json::from_slice::<Value>(&out.stdout).unwrap()["continuous_ns"]
            .as_u64()
            .unwrap()
    });
    let states = [
        json!({"kind":"value","source":if large { "V".repeat(3600) } else { "value-marker".into() },"value":if large { "V".repeat(3600) } else { "value-marker".into() }}),
        json!({"kind":"empty"}),
        json!({"kind":"missing"}),
        json!({"kind":"inaccessible"}),
        json!({"kind":"ambiguous","candidates":["left","right"]}),
        json!({"kind":"invalid","source":"NaN","reason":"not numeric"}),
    ];
    let fields: Vec<_> = states.into_iter().enumerate().map(|(i,state)| json!({
        "name":format!("field-{i}"),"state":state,
        "source":{"observation":{"run_id":run,"surface_id":"surface-1","attachment_generation":1,
        "frame_id":"frame-1","document_id":"doc-1","activation_generation":1,"node_generation":1,
        "capture_id":"capture-1","capture_start_ns":capture,"capture_end_ns":capture,"security_origin":"https://fixture.test"},
        "node_id":if i==2 || i==3 { None } else { Some(100+i as i64) },
        "visibility":"layout-present-occlusion-unknown","normalization":"identity",
        "fragment":match i { 0 => Some(if large { "V".repeat(3600) } else { "value-marker".into() }), 1=>Some(String::new()), 5=>Some("NaN".into()), _=>None }}
    })).map(|mut f| { if f["source"]["fragment"].is_null() { f["source"].as_object_mut().unwrap().remove("fragment"); } f }).collect();
    json!({"schema_version":"fixture-v1","pattern_version":"deterministic-v1","partial":true,"rows":[{"fields":fields}]})
}
#[test]
fn exact_review_duplicate_identity_changed_retention_and_clean_native_reopen() {
    let dir = directory("exact");
    let mut c = Client::open(dir.clone(), "first-run");
    let before = clock_ns();
    let stage = c.stage("first-run", false);
    let after = clock_ns();
    let reviewed = c.call(
        "table_review",
        json!({"staging_id":stage,"retention_ms":60_000}),
    );
    let deadline = reviewed["publication_guard"]["valid_until_ns"]
        .as_u64()
        .unwrap();
    assert!((before + 86_400_000_000_000..=after + 86_400_000_000_000).contains(&deadline));
    let r = reviewed["review"].clone();
    let a = c.call("table_approve", json!({"review":r}));
    let shorter = c.call(
        "table_review",
        json!({"staging_id":stage,"retention_ms":100}),
    )["review"]
        .clone();
    assert_eq!(
        c.call("table_approve", json!({"review":shorter}))["op"],
        "table_error"
    );
    let id = c.call("table_commit", json!({"approval_id":a["approval_id"]}))["commit_id"]
        .as_str()
        .unwrap()
        .to_string();
    let end = Instant::now() + Duration::from_secs(5);
    while c.call("table_status", json!({"commit_id":id}))["state"] != "committed" {
        assert!(Instant::now() < end);
    }
    let read = c.call("table_read", json!({"commit_id":id}));
    assert_eq!(read["batch"], batch("first-run", false));
    let db = c.db();
    let content: String = db
        .query_row("SELECT review FROM commits WHERE id=?1", [&id], |r| {
            r.get(0)
        })
        .unwrap();
    assert_eq!(content, r["content"].as_str().unwrap());
    let (boot, deadline): (String, i64) = db
        .query_row(
            "SELECT boot_id,expires_ns FROM commits WHERE id=?1",
            [&id],
            |r| Ok((r.get(0)?, r.get(1)?)),
        )
        .unwrap();
    assert_eq!(
        read["publication_guard"],
        json!({"boot_id":boot,"valid_until_ns":deadline})
    );
    let list = c.call("table_list", json!({}));
    assert_eq!(list["commit_ids"], json!([id]));
    assert_eq!(list["publication_guard"], read["publication_guard"]);
    assert_eq!(
        db.query_row("SELECT count(*) FROM rows", [], |r| r.get::<_, i64>(0))
            .unwrap(),
        1
    );
    drop(db);
    c.finish();
    let mut reopened = Client::open(dir.clone(), "second-run");
    assert_eq!(
        reopened.call("table_list", json!({}))["commit_ids"],
        json!([id])
    );
    assert_eq!(
        reopened.call("table_read", json!({"commit_id":id}))["batch"],
        batch("first-run", false)
    );
    reopened.finish();
    std::fs::remove_dir_all(dir).unwrap();
}
#[test]
fn blocked_stdout_does_not_prevent_idle_native_expiry_and_dirty_transport_exit() {
    let dir = directory("expiry");
    let mut c = Client::open(dir.clone(), "expiry-run");
    let (_id, _) = c.save("expiry-run", 800);
    let stage = c.stage("expiry-run", true);
    for _ in 0..7 {
        c.request(
            "table_review",
            json!({"staging_id":stage,"retention_ms":60_000}),
        );
    }
    let db = c.db();
    let end = Instant::now() + Duration::from_secs(4);
    while db
        .query_row("SELECT count(*) FROM rows", [], |r| r.get::<_, i64>(0))
        .unwrap()
        != 0
    {
        assert!(Instant::now() < end, "blocked stdout stopped expiry");
        thread::sleep(Duration::from_millis(10));
    }
    while c.child.try_wait().unwrap().is_none() {
        assert!(Instant::now() < end, "blocked writer did not terminate");
        thread::sleep(Duration::from_millis(10));
    }
    assert!(!c.child.wait().unwrap().success());
    assert_eq!(
        db.query_row("SELECT dirty FROM meta", [], |r| r.get::<_, i64>(0))
            .unwrap(),
        1
    );
    drop(db);
    drop(c);
    std::fs::remove_dir_all(dir).unwrap();
}
#[test]
fn blocked_stdout_stop_rejects_actual_sqlite_lock_stalled_preparation() {
    let dir = directory("stop");
    let mut c = Client::open(dir.clone(), "stop-run");
    let stage = c.stage("stop-run", true);
    let review = c.call(
        "table_review",
        json!({"staging_id":stage,"retention_ms":60_000}),
    )["review"]
        .clone();
    let a = c.call("table_approve", json!({"review":review}));
    let db = c.db();
    db.execute_batch("BEGIN IMMEDIATE").unwrap();
    let id = c.call("table_commit", json!({"approval_id":a["approval_id"]}))["commit_id"]
        .as_str()
        .unwrap()
        .to_string();
    for _ in 0..7 {
        c.request(
            "table_review",
            json!({"staging_id":stage,"retention_ms":60_000}),
        );
    }
    // Let actual large replies reach and block the unread OS pipe first.
    thread::sleep(Duration::from_millis(900));
    assert!(
        c.child.try_wait().unwrap().is_none(),
        "service died before Stop"
    );
    let stop_id = c.request("stop_all", json!({}));
    thread::sleep(Duration::from_millis(150));
    db.execute_batch("ROLLBACK").unwrap();
    thread::sleep(Duration::from_millis(100));
    assert!(
        c.child.try_wait().unwrap().is_none(),
        "failure cannot stand in for Stop"
    );
    assert_eq!(
        db.query_row("SELECT count(*) FROM rows", [], |r| r.get::<_, i64>(0))
            .unwrap(),
        0
    );
    // Resume stdout only after checking effects. Require the actual Stop
    // generation too: process death alone could also leave zero rows.
    let mut stopped = false;
    for _ in 0..8 {
        let reply = c.receive();
        if reply["id"] == stop_id {
            assert_eq!(reply["op"], "stopped");
            assert_eq!(reply["stop_generation"], 1);
            stopped = true;
        }
    }
    assert!(stopped);
    assert_eq!(
        db.query_row("SELECT count(*) FROM rows", [], |r| r.get::<_, i64>(0))
            .unwrap(),
        0
    );
    assert_eq!(
        db.query_row("SELECT count(*) FROM commits WHERE id=?1", [&id], |r| r
            .get::<_, i64>(0))
            .unwrap(),
        0,
        "Stop failed to delete preparation before transport deadline"
    );
    drop(db);
    c.finish();
    std::fs::remove_dir_all(dir).unwrap();
}

fn clock_ns() -> u64 {
    let output = Command::new(probe()).output().unwrap();
    serde_json::from_slice::<Value>(&output.stdout).unwrap()["continuous_ns"]
        .as_u64()
        .unwrap()
}
#[test]
fn nested_positional_duplicate_and_unknown_source_records_have_zero_actual_rows() {
    for kind in 0..3 {
        let dir = directory(&format!("invalid-{kind}"));
        let mut c = Client::open(dir.clone(), "invalid-run");
        let mut b = batch("invalid-run", false);
        match kind {
            0 => b["rows"][0]["fields"][0]["source"]["surprise"] = true.into(),
            1 => b["rows"][0]["fields"][0]["source"]["observation"] = json!(["invalid-run"]),
            _ => {}
        }
        let request = json!({"version":1,"op":"table_stage","id":c.next,"batch":b});
        let mut text = request.to_string();
        if kind == 2 {
            text = text.replace("\"node_id\":100", "\"node_id\":100,\"node_id\":101");
        }
        writeln!(c.input, "{text}").unwrap();
        c.input.flush().unwrap();
        assert_eq!(
            c.receive(),
            json!({"version":1,"op":"error","code":"invalid_message"})
        );
        assert_eq!(
            c.db()
                .query_row("SELECT count(*) FROM rows", [], |r| r.get::<_, i64>(0))
                .unwrap(),
            0
        );
        drop(c);
        std::fs::remove_dir_all(dir).unwrap();
    }
}
#[test]
fn stop_progresses_during_real_clock_subprocess_stall_without_database_effects() {
    use std::os::unix::fs::PermissionsExt;
    let dir = directory("clock-stall");
    std::fs::create_dir_all(&dir).unwrap();
    let stall = dir.join("clock-probe");
    std::fs::write(&stall, "#!/bin/sh\nexec /bin/sleep 5\n").unwrap();
    std::fs::set_permissions(&stall, std::fs::Permissions::from_mode(0o700)).unwrap();
    let mut child = Command::new(env!("CARGO_BIN_EXE_bow-shock-controller"))
        .arg("--table-db")
        .arg(dir.join("tables.sqlite"))
        .arg("--clock-probe")
        .arg(stall)
        .args(["--owned-origin", "https://fixture.test"])
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::null())
        .spawn()
        .unwrap();
    let mut stdin = child.stdin.take().unwrap();
    writeln!(
        stdin,
        "{}",
        json!({"version":1,"op":"initialize","run_id":"clock-run"})
    )
    .unwrap();
    let mut stdout = BufReader::new(child.stdout.take().unwrap());
    let mut line = String::new();
    stdout.read_line(&mut line).unwrap();
    assert_eq!(
        serde_json::from_str::<Value>(&line).unwrap()["op"],
        "initialized"
    );
    thread::sleep(Duration::from_millis(50));
    writeln!(stdin, "{}", json!({"version":1,"op":"stop_all","id":1})).unwrap();
    line.clear();
    stdout.read_line(&mut line).unwrap();
    assert_eq!(
        serde_json::from_str::<Value>(&line).unwrap(),
        json!({"version":1,"op":"stopped","run_id":"clock-run","id":1,"stop_generation":1,"active_powers":[]})
    );
    let end = Instant::now() + Duration::from_secs(2);
    while child.try_wait().unwrap().is_none() {
        assert!(Instant::now() < end);
        thread::sleep(Duration::from_millis(10));
    }
    assert!(!child.wait().unwrap().success());
    assert!(!dir.join("tables.sqlite").exists());
    std::fs::remove_dir_all(dir).unwrap();
}

#[test]
fn terminal_overflow_reaps_the_exact_owned_clock_subprocess_before_exit() {
    use std::os::unix::fs::PermissionsExt;
    let dir = directory("owned-clock");
    std::fs::create_dir_all(&dir).unwrap();
    let pidfile = dir.join("clock.pid");
    let script = dir.join("clock");
    let quoted = format!("'{}'", pidfile.display().to_string().replace('\'', "'\\''"));
    std::fs::write(
        &script,
        format!("#!/bin/sh\nif [ \"$1\" = '--setup' ]; then exit 0; fi\nprintf '%s' \"$$\" > {quoted}\nexec /bin/sleep 10\n"),
    )
    .unwrap();
    std::fs::set_permissions(&script, std::fs::Permissions::from_mode(0o700)).unwrap();
    // Verify fresh executable availability outside the runtime cancellation
    // scenario; the service's no-argument invocation still creates the real PID.
    assert!(
        Command::new(&script)
            .arg("--setup")
            .status()
            .unwrap()
            .success()
    );
    let mut child = Command::new(env!("CARGO_BIN_EXE_bow-shock-controller"))
        .arg("--table-db")
        .arg(dir.join("tables.sqlite"))
        .arg("--clock-probe")
        .arg(&script)
        .args(["--owned-origin", "https://fixture.test"])
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::null())
        .spawn()
        .unwrap();
    let mut stdin = child.stdin.take().unwrap();
    writeln!(
        stdin,
        "{}",
        json!({"version":1,"op":"initialize","run_id":"owned-clock-run"})
    )
    .unwrap();
    let end = Instant::now() + Duration::from_secs(3);
    let pid = loop {
        if let Ok(contents) = std::fs::read_to_string(&pidfile)
            && let Ok(pid) = contents.parse::<u32>()
        {
            break pid;
        }
        assert!(Instant::now() < end);
        thread::sleep(Duration::from_millis(1));
    };
    struct Cleanup(u32);
    impl Drop for Cleanup {
        fn drop(&mut self) {
            let _ = Command::new("kill")
                .args(["-KILL", &self.0.to_string()])
                .stderr(Stdio::null())
                .status();
        }
    }
    let cleanup = Cleanup(pid);
    for id in 1..20 {
        writeln!(
            stdin,
            "{}",
            json!({"version":1,"op":"table_status","id":id,"commit_id":null})
        )
        .unwrap();
    }
    stdin.flush().unwrap();
    while child.try_wait().unwrap().is_none() {
        assert!(Instant::now() < end);
        thread::sleep(Duration::from_millis(1));
    }
    assert!(!child.wait().unwrap().success());
    let snapshot = Command::new("ps")
        .args(["-p", &pid.to_string(), "-o", "pid=,ppid=,stat=,comm="])
        .output()
        .unwrap();
    assert!(
        snapshot.stdout.is_empty(),
        "owned clock remains after terminal exit: {}",
        String::from_utf8_lossy(&snapshot.stdout)
    );
    std::mem::forget(cleanup);
    std::fs::remove_dir_all(dir).unwrap();
}
#[test]
fn ambiguous_whole_cell_requires_literal_candidates_and_missing_node_key_is_not_null() {
    let dir = directory("ambiguous-grounding");
    let mut c = Client::open(dir.clone(), "ambiguous-run");
    let mut b = batch("ambiguous-run", false);
    b["rows"][0]["fields"][4]["source"]["fragment"] = "invented selected fragment".into();
    assert_eq!(
        c.call("table_stage", json!({"batch":b}))["op"],
        "table_error"
    );
    b["rows"][0]["fields"][4]["source"]["fragment"] = "left / right".into();
    assert_eq!(
        c.call("table_stage", json!({"batch":b}))["op"],
        "table_staged"
    );
    b["rows"][0]["fields"][2]["source"]
        .as_object_mut()
        .unwrap()
        .remove("node_id");
    c.request("table_stage", json!({"batch":b}));
    assert_eq!(
        c.receive(),
        json!({"version":1,"op":"error","code":"invalid_message"})
    );
    assert_eq!(
        c.db()
            .query_row("SELECT count(*) FROM rows", [], |r| r.get::<_, i64>(0))
            .unwrap(),
        0
    );
    drop(c);
    std::fs::remove_dir_all(dir).unwrap();
}

#[test]
fn transport_failure_reaps_both_controller_and_sqlite_owned_clock_queries() {
    use std::os::unix::fs::PermissionsExt;
    let dir = directory("sqlite-query-ownership");
    std::fs::create_dir_all(&dir).unwrap();
    let first = dir.join("first");
    let pids = dir.join("pids");
    let script = dir.join("clock");
    fn quote(path: &Path) -> String {
        format!("'{}'", path.display().to_string().replace('\'', "'\\''"))
    }
    let text = format!(
        "#!/bin/sh\nif [ ! -f {} ]; then\n printf 'first' > {}\n exec {}\nfi\nprintf '%s\\n' \"$$\" >> {}\nexec /bin/sleep 10\n",
        quote(&first),
        quote(&first),
        quote(probe()),
        quote(&pids)
    );
    std::fs::write(&script, text).unwrap();
    std::fs::set_permissions(&script, std::fs::Permissions::from_mode(0o700)).unwrap();
    // Check the newly created wrapper's actual first-sample branch as setup.
    // The service still executes a new sample; no witness is reused.
    let setup = Command::new(&script).output().unwrap();
    assert!(setup.status.success());
    let _: bow_shock_evidence::ClockWitness = serde_json::from_slice(&setup.stdout).unwrap();
    std::fs::remove_file(&first).unwrap();
    let mut child = Command::new(env!("CARGO_BIN_EXE_bow-shock-controller"))
        .arg("--table-db")
        .arg(dir.join("tables.sqlite"))
        .arg("--clock-probe")
        .arg(&script)
        .args(["--owned-origin", "https://fixture.test"])
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::inherit())
        .spawn()
        .unwrap();
    let mut stdin = child.stdin.take().unwrap();
    writeln!(
        stdin,
        "{}",
        json!({"version":1,"op":"initialize","run_id":"sqlite-owner"})
    )
    .unwrap();
    let end = Instant::now() + Duration::from_secs(3);
    let owned = loop {
        let ids: Vec<u32> = std::fs::read_to_string(&pids)
            .unwrap_or_default()
            .lines()
            .filter_map(|p| p.parse().ok())
            .collect();
        if ids.len() == 2 {
            break ids;
        }
        assert!(
            child.try_wait().unwrap().is_none(),
            "setup never reached two live query owners; observed PIDs={ids:?}"
        );
        assert!(
            Instant::now() < end,
            "setup never reached two owners; observed PIDs={ids:?}"
        );
        thread::sleep(Duration::from_millis(1));
    };
    struct Cleanup(Vec<u32>);
    impl Drop for Cleanup {
        fn drop(&mut self) {
            for pid in &self.0 {
                let _ = Command::new("kill")
                    .args(["-KILL", &pid.to_string()])
                    .stderr(Stdio::null())
                    .status();
            }
        }
    }
    let cleanup = Cleanup(owned.clone());
    assert!(
        dir.join("tables.sqlite").exists(),
        "SQLite worker has reached native startup query"
    );
    // Two simultaneous queries: the serialized control sampler and the only
    // SQLite worker. Break stdout while both actual child processes are alive.
    drop(child.stdout.take());
    writeln!(stdin, "{}", json!({"version":1,"op":"ping","id":1})).unwrap();
    while child.try_wait().unwrap().is_none() {
        assert!(Instant::now() < end);
        thread::sleep(Duration::from_millis(1));
    }
    assert!(!child.wait().unwrap().success());
    for pid in owned {
        let snapshot = Command::new("ps")
            .args(["-p", &pid.to_string(), "-o", "pid=,ppid=,stat=,comm="])
            .output()
            .unwrap();
        assert!(
            snapshot.stdout.is_empty(),
            "owned query survived: {}",
            String::from_utf8_lossy(&snapshot.stdout)
        );
    }
    let db = Connection::open(dir.join("tables.sqlite")).unwrap();
    assert_eq!(
        db.query_row("SELECT count(*) FROM rows", [], |r| r.get::<_, i64>(0))
            .unwrap(),
        0
    );
    drop(db);
    std::mem::forget(cleanup);
    std::fs::remove_dir_all(dir).unwrap();
}
