#![cfg(target_os = "macos")]

use bow_shock_evidence::*;
use rusqlite::Connection;
use std::{
    path::{Path, PathBuf},
    process::{Command, Stdio},
    thread,
    time::{Duration, Instant},
};

fn probe() -> PathBuf {
    if let Some(path) = std::env::var_os("BOW_SHOCK_NATIVE_CLOCK_PROBE") {
        return path.into();
    }
    let root = Path::new(env!("CARGO_MANIFEST_DIR")).join("../..");
    let out = std::env::temp_dir().join(format!("bow-shock-native-clock-{}", std::process::id()));
    let status = Command::new("clang++")
        .args(["-std=c++17", "-fobjc-arc", "-framework", "Foundation", "-I"])
        .arg(root.join("native/cef"))
        .arg(root.join("native/cef/continuous_clock.mm"))
        .arg(root.join("tests/native_clock_probe.mm"))
        .arg("-o")
        .arg(&out)
        .status()
        .unwrap();
    assert!(
        status.success(),
        "compile actual owned native clock producer"
    );
    out
}
fn sample(probe: &Path) -> ClockWitness {
    let output = Command::new(probe).output().unwrap();
    assert!(output.status.success());
    serde_json::from_slice(&output.stdout).unwrap()
}
fn wait(store: &mut Store, probe: &Path, predicate: impl Fn(&Store) -> bool) {
    let end = Instant::now() + Duration::from_secs(8);
    loop {
        store.poll_at(sample(probe)).unwrap();
        if predicate(store) {
            return;
        }
        assert!(
            Instant::now() < end,
            "store timeout {:?} {:?}",
            store.health(),
            store.last_error()
        );
        thread::sleep(Duration::from_millis(2));
    }
}
fn batch() -> Batch {
    Batch {
        schema_version: "schema-v1".into(),
        pattern_version: "pattern-v1".into(),
        partial: true,
        rows: vec![Row {
            fields: vec![Field {
                name: "marker".into(),
                state: FieldState::Value {
                    source: "retained-marker".into(),
                    value: "retained-marker".into(),
                },
                source: Source {
                    observation: ObservationRef {
                        run_id: "first-run".into(),
                        surface_id: "surface".into(),
                        attachment_generation: 1,
                        frame_id: "frame".into(),
                        document_id: "document".into(),
                        activation_generation: 1,
                        node_generation: 1,
                        capture_id: "capture".into(),
                        capture_start_ns: None,
                        capture_end_ns: None,
                        security_origin: "https://fixture.test".into(),
                    },
                    node_id: Some(42),
                    visibility: "layout-present".into(),
                    normalization: "identity".into(),
                    fragment: None,
                },
            }],
        }],
    }
}
fn save(path: &Path, probe: &Path, ttl: u64) -> String {
    let mut store = Store::open_with_clock(path, "first-run", sample(probe), probe).unwrap();
    wait(&mut store, probe, |s| s.health() == Health::Ready);
    store
        .set_origins_at(vec!["https://fixture.test".into()], sample(probe))
        .unwrap();
    let stage = store
        .stage_at(batch(), SourcePolicy::local_rows(60_000), sample(probe))
        .unwrap();
    let review = store.review_at(&stage, ttl, sample(probe)).unwrap();
    let approved = store.approve_at(&review, sample(probe)).unwrap();
    let id = store.commit_at(&approved, sample(probe)).unwrap();
    wait(&mut store, probe, |s| {
        s.status(&id) == Some(CommitState::Committed)
    });
    assert!(
        store.read(&id).is_err(),
        "clock mode has no cached-read backdoor"
    );
    assert_eq!(store.read_at(&id, sample(probe)).unwrap(), batch());
    store.close_at(sample(probe)).unwrap();
    wait(&mut store, probe, |s| s.health() == Health::Closed);
    id
}

#[test]
fn clean_actual_native_process_restart_recovers_exact_identity_and_rows() {
    let probe = probe();
    let path = std::env::temp_dir().join(format!(
        "bow-shock-clean-native-{}.sqlite",
        std::process::id()
    ));
    let status = Command::new(std::env::current_exe().unwrap())
        .args(["--ignored", "--exact", "clean_process_fixture"])
        .env("BOW_SHOCK_NATIVE_CLOCK_PROBE", &probe)
        .env("BOW_SHOCK_NATIVE_CLOCK_DB", &path)
        .stdout(Stdio::null())
        .status()
        .unwrap();
    assert!(status.success());
    let id = std::fs::read_to_string(path.with_extension("commit-id")).unwrap();
    let conn = Connection::open(&path).unwrap();
    assert_eq!(
        conn.query_row("SELECT dirty FROM meta", [], |r| r.get::<_, i64>(0))
            .unwrap(),
        0
    );
    let original: String = conn
        .query_row("SELECT review FROM commits WHERE id=?1", [&id], |r| {
            r.get(0)
        })
        .unwrap();
    let mut reopened = Store::open_with_clock(&path, "second-run", sample(&probe), &probe).unwrap();
    wait(&mut reopened, &probe, |s| s.health() != Health::Opening);
    assert_eq!(reopened.health(), Health::Ready);
    assert_eq!(reopened.status(&id), Some(CommitState::Committed));
    assert_eq!(reopened.read_at(&id, sample(&probe)).unwrap(), batch());
    assert!(reopened.read(&id).is_err());
    assert_eq!(
        conn.query_row("SELECT review FROM commits WHERE id=?1", [&id], |r| r
            .get::<_, String>(0))
            .unwrap(),
        original
    );
    assert_eq!(
        conn.query_row("SELECT count(*) FROM rows", [], |r| r.get::<_, i64>(0))
            .unwrap(),
        1
    );
}

#[test]
fn expired_same_boot_reopen_purges_actual_rows_and_unknown_boot_stays_denied() {
    let probe = probe();
    let path = std::env::temp_dir().join(format!(
        "bow-shock-expired-native-{}.sqlite",
        std::process::id()
    ));
    let id = save(&path, &probe, 1000);
    thread::sleep(Duration::from_millis(1100));
    let mut reopened =
        Store::open_with_clock(&path, "expired-run", sample(&probe), &probe).unwrap();
    wait(&mut reopened, &probe, |s| s.health() != Health::Opening);
    assert_eq!(reopened.health(), Health::Ready);
    assert!(reopened.read_at(&id, sample(&probe)).is_err());
    let conn = Connection::open(&path).unwrap();
    assert_eq!(
        conn.query_row("SELECT count(*) FROM rows", [], |r| r.get::<_, i64>(0))
            .unwrap(),
        0
    );
    reopened.close_at(sample(&probe)).unwrap();
    wait(&mut reopened, &probe, |s| s.health() == Health::Closed);
    // Controlled incompatible persisted boot witness, using actual new samples.
    conn.execute(
        "UPDATE meta SET boot_id='00000000-0000-0000-0000-000000000000',dirty=1",
        [],
    )
    .unwrap();
    let mut unknown = Store::open_with_clock(&path, "unknown-run", sample(&probe), &probe).unwrap();
    wait(&mut unknown, &probe, |s| s.health() != Health::Opening);
    assert_eq!(unknown.health(), Health::RestrictionUnknown);
    assert!(unknown.read_at(&id, sample(&probe)).is_err());
}

#[test]
fn actual_worker_clock_expires_stalled_writer_without_actor_clock_updates() {
    let probe = probe();
    let path = std::env::temp_dir().join(format!(
        "bow-shock-starved-clock-{}.sqlite",
        std::process::id()
    ));
    let mut store = Store::open_with_clock(&path, "first-run", sample(&probe), &probe).unwrap();
    wait(&mut store, &probe, |s| s.health() == Health::Ready);
    store
        .set_origins_at(vec!["https://fixture.test".into()], sample(&probe))
        .unwrap();
    let stage = store
        .stage_at(batch(), SourcePolicy::local_rows(60_000), sample(&probe))
        .unwrap();
    let review = store.review_at(&stage, 1000, sample(&probe)).unwrap();
    let approval = store.approve_at(&review, sample(&probe)).unwrap();
    let id = store.commit_at(&approval, sample(&probe)).unwrap();
    wait(&mut store, &probe, |s| {
        s.status(&id) == Some(CommitState::Admitted)
    });
    let conn = Connection::open(&path).unwrap();
    conn.execute_batch("BEGIN IMMEDIATE").unwrap();
    let deadline: i64 = conn
        .query_row("SELECT expires_ns FROM commits WHERE id=?1", [&id], |r| {
            r.get(0)
        })
        .unwrap();
    store.poll_at(sample(&probe)).unwrap();
    thread::sleep(Duration::from_millis(1100)); // No authority poll/sample during this stall.
    assert!(sample(&probe).continuous_ns >= deadline as u64);
    conn.execute_batch("ROLLBACK").unwrap();
    thread::sleep(Duration::from_millis(200)); // Let actual worker finish, still no authority poll.
    assert_eq!(
        conn.query_row("SELECT count(*) FROM rows", [], |r| r.get::<_, i64>(0))
            .unwrap(),
        0,
        "cached authority time must not authorize expired row persistence"
    );
    assert_eq!(
        conn.query_row("SELECT state FROM commits WHERE id=?1", [&id], |r| r
            .get::<_, String>(0))
            .unwrap(),
        "admitted"
    );
    wait(&mut store, &probe, |s| {
        s.status(&id) == Some(CommitState::Deleted)
    });
    assert_eq!(
        conn.query_row("SELECT count(*) FROM commits", [], |r| r.get::<_, i64>(0))
            .unwrap(),
        0
    );
}

#[test]
fn clean_incompatible_boot_keeps_actual_retained_rows_quarantined() {
    let probe = probe();
    let path = std::env::temp_dir().join(format!(
        "bow-shock-other-boot-{}.sqlite",
        std::process::id()
    ));
    let id = save(&path, &probe, 60_000);
    let conn = Connection::open(&path).unwrap();
    conn.execute(
        "UPDATE meta SET boot_id='00000000-0000-0000-0000-000000000000'",
        [],
    )
    .unwrap();
    assert_eq!(
        conn.query_row("SELECT dirty FROM meta", [], |r| r.get::<_, i64>(0))
            .unwrap(),
        0
    );
    let mut reopened =
        Store::open_with_clock(&path, "different-boot", sample(&probe), &probe).unwrap();
    wait(&mut reopened, &probe, |s| s.health() != Health::Opening);
    assert_eq!(reopened.health(), Health::RestrictionUnknown);
    assert!(reopened.read_at(&id, sample(&probe)).is_err());
    assert_eq!(
        conn.query_row("SELECT count(*) FROM rows", [], |r| r.get::<_, i64>(0))
            .unwrap(),
        1
    );
}

#[test]
#[ignore]
fn clean_process_fixture() {
    let probe = probe();
    let path = PathBuf::from(std::env::var_os("BOW_SHOCK_NATIVE_CLOCK_DB").unwrap());
    let id = save(&path, &probe, 60_000);
    std::fs::write(path.with_extension("commit-id"), id).unwrap();
}
