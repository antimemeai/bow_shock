use bow_shock_evidence::*;
use rusqlite::Connection;
use std::{
    ops::{Deref, DerefMut},
    path::{Path, PathBuf},
    process::{Child, Command, Stdio},
    thread,
    time::{Duration, Instant},
};

struct ChildGuard(Child);
impl Deref for ChildGuard {
    type Target = Child;
    fn deref(&self) -> &Child {
        &self.0
    }
}
impl DerefMut for ChildGuard {
    fn deref_mut(&mut self) -> &mut Child {
        &mut self.0
    }
}
impl Drop for ChildGuard {
    fn drop(&mut self) {
        let _ = self.0.kill();
        let _ = self.0.wait();
    }
}

fn wait(store: &mut Store, predicate: impl Fn(&Store) -> bool) {
    let end = Instant::now() + Duration::from_secs(5);
    loop {
        store.poll();
        if predicate(store) {
            return;
        }
        assert!(
            Instant::now() < end,
            "store timeout: {:?} {:?}",
            store.health(),
            store.last_error()
        );
        thread::sleep(Duration::from_millis(2));
    }
}
fn fixture_batch() -> Batch {
    Batch {
        schema_version: "v1".into(),
        pattern_version: "v1".into(),
        partial: true,
        rows: vec![Row {
            fields: vec![Field {
                name: "marker".into(),
                state: FieldState::Value {
                    source: "crash-marker".into(),
                    value: "crash-marker".into(),
                },
                source: Source {
                    observation: ObservationRef {
                        run_id: "child-run".into(),
                        surface_id: "surface".into(),
                        attachment_generation: 1,
                        frame_id: "root".into(),
                        document_id: "doc".into(),
                        activation_generation: 1,
                        node_generation: 1,
                        capture_id: "capture".into(),
                        security_origin: "https://fixture.test".into(),
                    },
                    node_id: Some(42),
                    visibility: "layout-present".into(),
                    normalization: "identity".into(),
                },
            }],
        }],
    }
}
fn child(path: &Path, mode: &str) -> ChildGuard {
    ChildGuard(
        Command::new(std::env::current_exe().unwrap())
            .args(["--ignored", "--exact", "fixture_process", "--nocapture"])
            .env("BOW_SHOCK_EVIDENCE_PROCESS_PATH", path)
            .env("BOW_SHOCK_EVIDENCE_PROCESS_MODE", mode)
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .spawn()
            .unwrap(),
    )
}
fn wait_file(child: &mut Child, path: &Path) {
    let end = Instant::now() + Duration::from_secs(5);
    while !path.exists() {
        assert!(
            child.try_wait().unwrap().is_none(),
            "fixture process exited before actual boundary"
        );
        assert!(Instant::now() < end, "fixture boundary timeout");
        thread::sleep(Duration::from_millis(2));
    }
}
fn database_count(path: &Path) -> (i64, i64) {
    let conn = Connection::open(path).unwrap();
    (
        conn.query_row("SELECT count(*) FROM rows", [], |r| r.get(0))
            .unwrap(),
        conn.query_row("SELECT count(*) FROM commits", [], |r| r.get(0))
            .unwrap(),
    )
}

#[test]
fn killed_writer_unknown_restart_no_replay_and_exclusive_recovery() {
    for mode in ["admitted", "committed"] {
        let path = std::env::temp_dir().join(format!(
            "bow-shock-process-{}-{mode}.sqlite",
            std::process::id()
        ));
        let mut process = child(&path, mode);
        wait_file(&mut process, &path.with_extension("ready"));
        let before = database_count(&path);
        assert_eq!(before, if mode == "admitted" { (0, 1) } else { (1, 1) });
        let mut contender = Store::open(&path, "contender").unwrap();
        wait(&mut contender, |s| s.health() != Health::Opening);
        assert_eq!(
            contender.health(),
            Health::Failed,
            "live writer must keep sole ownership"
        );
        assert!(contender.recover_purge().is_err());
        assert_eq!(database_count(&path), before);
        process.kill().unwrap();
        process.wait().unwrap();
        let mut reopened = Store::open(&path, "new-run").unwrap();
        wait(&mut reopened, |s| s.health() != Health::Opening);
        assert_eq!(reopened.health(), Health::RestrictionUnknown);
        assert!(reopened.read("child-run:commit:2").is_err());
        assert_eq!(
            database_count(&path),
            before,
            "no automatic replay or silent purge"
        );
        reopened.recover_purge().unwrap();
        wait(&mut reopened, |s| s.health() == Health::Ready);
        assert_eq!(database_count(&path), (0, 0));
        reopened.close().unwrap();
        wait(&mut reopened, |s| s.health() == Health::Closed);
        // Clean empty restart is usable; no retained clock needs reconstructing.
        let mut empty = Store::open(&path, "third-run").unwrap();
        wait(&mut empty, |s| s.health() != Health::Opening);
        assert_eq!(empty.health(), Health::Ready);
    }
}

#[test]
fn failed_deletion_fence_write_then_crash_cannot_reopen_marker() {
    let path = std::env::temp_dir().join(format!(
        "bow-shock-failed-fence-{}.sqlite",
        std::process::id()
    ));
    let mut process = child(&path, "committed");
    wait_file(&mut process, &path.with_extension("ready"));
    let lock = Connection::open(&path).unwrap();
    lock.execute_batch("BEGIN IMMEDIATE").unwrap();
    std::fs::write(path.with_extension("delete"), b"delete now").unwrap();
    wait_file(&mut process, &path.with_extension("denied"));
    assert_eq!(database_count(&path), (1, 1));
    assert_eq!(
        lock.query_row("SELECT count(*) FROM deletions", [], |r| r.get::<_, i64>(0))
            .unwrap(),
        0,
        "the write lock prevents durable restriction intent"
    );
    process.kill().unwrap();
    process.wait().unwrap();
    lock.execute_batch("ROLLBACK").unwrap();
    let mut store = Store::open(&path, "recovery-run").unwrap();
    wait(&mut store, |s| s.health() != Health::Opening);
    assert_eq!(store.health(), Health::RestrictionUnknown);
    assert!(
        store.read("child-run:commit:2").is_err(),
        "missing fence cannot authorize old data"
    );
    store.recover_purge().unwrap();
    wait(&mut store, |s| s.health() == Health::Ready);
    assert_eq!(database_count(&path), (0, 0));
}

// Fixed test scenarios only; this ignored test is an actual separate process,
// never a product command or a production fault-injection switch.
#[test]
#[ignore]
fn fixture_process() {
    let path =
        PathBuf::from(std::env::var_os("BOW_SHOCK_EVIDENCE_PROCESS_PATH").expect("fixture path"));
    let mode = std::env::var("BOW_SHOCK_EVIDENCE_PROCESS_MODE").expect("fixture mode");
    let mut store = Store::open(&path, "child-run").unwrap();
    wait(&mut store, |s| s.health() == Health::Ready);
    store
        .set_origins(vec!["https://fixture.test".into()])
        .unwrap();
    let stage = store
        .stage(fixture_batch(), SourcePolicy::local_rows(60_000))
        .unwrap();
    let review = store.review(&stage, 60_000).unwrap();
    let approval = store.approve(&review).unwrap();
    let id = store.commit(&approval).unwrap();
    let boundary = if mode == "admitted" {
        CommitState::Admitted
    } else {
        CommitState::Committed
    };
    wait(&mut store, |s| s.status(&id) == Some(boundary));
    std::fs::write(path.with_extension("ready"), b"actual DB boundary reached").unwrap();
    loop {
        if path.with_extension("delete").exists() {
            store.delete(&id).unwrap();
            assert!(store.read(&id).is_err());
            std::fs::write(
                path.with_extension("denied"),
                b"managed read denied before durable fence",
            )
            .unwrap();
            store.poll();
        }
        // The admitted child deliberately stops pumping before row dispatch.
        // Its actual durable record, not a model, supplies the crash boundary.
        thread::sleep(Duration::from_millis(2));
    }
}
