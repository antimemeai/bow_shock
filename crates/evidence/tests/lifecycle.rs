use bow_shock_evidence::*;
use rusqlite::Connection;
use std::{
    path::PathBuf,
    sync::atomic::{AtomicU64, Ordering},
    thread,
    time::{Duration, Instant},
};

static NEXT: AtomicU64 = AtomicU64::new(1);
fn path() -> PathBuf {
    std::env::temp_dir().join(format!(
        "bow-shock-evidence-{}-{}.sqlite",
        std::process::id(),
        NEXT.fetch_add(1, Ordering::Relaxed)
    ))
}
fn ready(path: &std::path::Path) -> Store {
    let mut store = Store::open(path, "test-run").unwrap();
    wait(&mut store, |s| s.health() == Health::Ready);
    store
        .set_origins(vec!["https://one.test".into(), "https://two.test".into()])
        .unwrap();
    store
}
fn wait(store: &mut Store, predicate: impl Fn(&Store) -> bool) {
    let end = Instant::now() + Duration::from_secs(5);
    loop {
        store.poll();
        if predicate(store) {
            return;
        }
        assert!(Instant::now() < end, "timed out: {:?}", store.health());
        thread::sleep(Duration::from_millis(2));
    }
}
fn batch() -> Batch {
    Batch {
        schema_version: "owned-list-v1".into(),
        pattern_version: "fixture-v1".into(),
        partial: true,
        rows: vec![Row {
            fields: vec![
                field(FieldState::Value {
                    source: "marker-42".into(),
                    value: "marker-42".into(),
                }),
                field(FieldState::Empty),
                field(FieldState::Missing),
                field(FieldState::Inaccessible),
                field(FieldState::Ambiguous {
                    candidates: vec!["a".into(), "b".into()],
                }),
                field(FieldState::Invalid {
                    source: "x".into(),
                    reason: "not a number".into(),
                }),
            ],
        }],
    }
}
fn field(state: FieldState) -> Field {
    let node_id = if matches!(state, FieldState::Missing | FieldState::Inaccessible) {
        None
    } else {
        Some(42)
    };
    Field {
        name: "column".into(),
        state,
        source: Source {
            observation: ObservationRef {
                run_id: "test-run".into(),
                surface_id: "owned-window".into(),
                attachment_generation: 1,
                frame_id: "native-root".into(),
                document_id: "loader-1".into(),
                activation_generation: 1,
                node_generation: 1,
                capture_id: "capture-1".into(),
                capture_start_ns: None,
                capture_end_ns: None,
                security_origin: "https://one.test".into(),
            },
            node_id,
            visibility: "layout-present-occlusion-unknown".into(),
            normalization: "identity".into(),
            fragment: None,
        },
    }
}
fn approve(store: &mut Store, batch: Batch, ttl: u64) -> String {
    let staged = store
        .stage(
            batch,
            SourcePolicy {
                allow_retained_rows: true,
                max_retention_ms: 60_000,
                session_ttl_ms: 60_000,
            },
        )
        .unwrap();
    let review = store.review(&staged, ttl).unwrap();
    let approval = store.approve(&review).unwrap();
    store.commit(&approval).unwrap()
}
fn persisted(path: &std::path::Path) -> (i64, i64) {
    let conn = Connection::open(path).unwrap();
    (
        conn.query_row("SELECT count(*) FROM rows", [], |r| r.get(0))
            .unwrap(),
        conn.query_row(
            "SELECT count(*) FROM commits WHERE state='committed'",
            [],
            |r| r.get(0),
        )
        .unwrap(),
    )
}

#[test]
fn exact_rows_all_states_duplicate_and_changed_approval() {
    let path = path();
    let mut store = ready(&path);
    let original = batch();
    let stage = store
        .stage(original.clone(), SourcePolicy::local_rows(60_000))
        .unwrap();
    let review = store.review(&stage, 60_000).unwrap();
    let approval = store.approve(&review).unwrap();
    let id = store.commit(&approval).unwrap();
    assert_eq!(store.commit(&approval).unwrap(), id);
    wait(&mut store, |s| {
        s.status(&id) == Some(CommitState::Committed)
    });
    assert_eq!(store.read(&id).unwrap(), original);
    assert_eq!(persisted(&path), (1, 1));
    assert!(
        store.revise(&stage, batch()).is_err(),
        "admitted stage must be terminal"
    );
    let mut wrong = review.clone();
    wrong.content.push(' ');
    assert!(store.approve(&wrong).is_err());
    store.close().unwrap();
    wait(&mut store, |s| s.health() == Health::Closed);
    let mut reopened = Store::open(&path, "fresh-run").unwrap();
    wait(&mut reopened, |s| s.health() != Health::Opening);
    assert_eq!(
        reopened.health(),
        Health::RestrictionUnknown,
        "restart lacks a verified expiry clock"
    );
    assert!(reopened.read(&id).is_err());
    assert_eq!(
        persisted(&path),
        (1, 1),
        "unknown restart cannot retry a commit"
    );
}

#[test]
fn changed_staging_invalidates_exact_review_and_origin_scope() {
    let path = path();
    let mut store = ready(&path);
    let stage = store
        .stage(batch(), SourcePolicy::local_rows(60_000))
        .unwrap();
    let old = store.review(&stage, 60_000).unwrap();
    store.revise(&stage, batch()).unwrap();
    assert!(store.approve(&old).is_err());
    let mut mixed = batch();
    mixed.rows[0].fields[1].source.observation.security_origin = "https://two.test".into();
    let id = approve(&mut store, mixed, 60_000);
    store.set_origins(vec!["https://one.test".into()]).unwrap();
    wait(&mut store, |s| s.status(&id) == Some(CommitState::Rejected));
    assert_eq!(persisted(&path), (0, 0));
}

#[test]
fn sqlite_write_lock_does_not_block_stop_or_allow_stale_preparation() {
    let path = path();
    let mut store = ready(&path);
    let lock = Connection::open(&path).unwrap();
    lock.execute_batch("BEGIN IMMEDIATE").unwrap();
    let id = approve(&mut store, batch(), 60_000);
    thread::sleep(Duration::from_millis(25));
    let before = Instant::now();
    store.stop();
    assert!(before.elapsed() < Duration::from_millis(100));
    assert_eq!(store.status(&id), Some(CommitState::Rejected));
    lock.execute_batch("ROLLBACK").unwrap();
    for _ in 0..100 {
        store.poll();
        thread::sleep(Duration::from_millis(2));
    }
    assert_eq!(persisted(&path), (0, 0));
}

#[test]
fn admitted_stop_finishes_but_required_delete_denies_and_purges_writer() {
    for delete in [false, true] {
        let path = path();
        let mut store = ready(&path);
        let id = approve(&mut store, batch(), 60_000);
        wait(&mut store, |s| s.status(&id) == Some(CommitState::Admitted));
        // Poll exposes the admitted durable boundary before it dispatches rows.
        let lock = Connection::open(&path).unwrap();
        lock.execute_batch("BEGIN IMMEDIATE").unwrap();
        store.poll();
        thread::sleep(Duration::from_millis(25));
        if delete {
            let before = Instant::now();
            store.delete(&id).unwrap();
            assert!(before.elapsed() < Duration::from_millis(100));
            assert!(store.read(&id).is_err());
        } else {
            store.stop();
        }
        lock.execute_batch("ROLLBACK").unwrap();
        let expected = if delete {
            CommitState::Deleted
        } else {
            CommitState::Committed
        };
        wait(&mut store, |s| s.status(&id) == Some(expected));
        assert_eq!(persisted(&path), if delete { (0, 0) } else { (1, 1) });
    }
}

#[test]
fn expiry_and_retention_transition_and_limits_are_direct() {
    let path = path();
    let mut store = ready(&path);
    let stage = store
        .stage(
            batch(),
            SourcePolicy {
                allow_retained_rows: false,
                max_retention_ms: 60_000,
                session_ttl_ms: 60_000,
            },
        )
        .unwrap();
    assert!(store.review(&stage, 1000).is_err());
    let mut oversized = batch();
    oversized.rows = vec![oversized.rows[0].clone(); 17];
    assert!(
        store
            .stage(oversized, SourcePolicy::local_rows(60_000))
            .is_err()
    );
    let mut unknown = batch();
    unknown.rows[0].fields[0].source.observation.security_origin = "null".into();
    assert!(
        store
            .stage(unknown, SourcePolicy::local_rows(60_000))
            .is_err()
    );
    let id = approve(&mut store, batch(), 100);
    wait(&mut store, |s| {
        s.status(&id) == Some(CommitState::Committed)
    });
    thread::sleep(Duration::from_millis(120));
    store.poll();
    assert!(store.read(&id).is_err());
    wait(&mut store, |s| s.status(&id) == Some(CommitState::Deleted));
    assert_eq!(persisted(&path), (0, 0));
}

#[test]
fn changed_retention_is_rejected_instead_of_reusing_old_approval() {
    let path = path();
    let mut store = ready(&path);
    let stage = store
        .stage(batch(), SourcePolicy::local_rows(60_000))
        .unwrap();
    let first = store.review(&stage, 60_000).unwrap();
    let approval = store.approve(&first).unwrap();
    let short = store.review(&stage, 100).unwrap();
    assert!(
        store.approve(&short).is_err(),
        "changed exact retention cannot reuse a long approval"
    );
    let duplicate = store.approve(&first).unwrap();
    let id = store.commit(&approval).unwrap();
    assert_eq!(store.commit(&duplicate).unwrap(), id);
    wait(&mut store, |s| {
        s.status(&id) == Some(CommitState::Committed)
    });
    let conn = Connection::open(&path).unwrap();
    let content: String = conn
        .query_row("SELECT review FROM commits WHERE id=?1", [&id], |r| {
            r.get(0)
        })
        .unwrap();
    assert_eq!(content, first.content);
    assert_ne!(content, short.content);
}

#[test]
fn sqlite_timeout_during_close_can_never_mark_failed_run_clean() {
    let path = path();
    let mut store = ready(&path);
    let id = approve(&mut store, batch(), 60_000);
    wait(&mut store, |s| s.status(&id) == Some(CommitState::Admitted));
    let lock = Connection::open(&path).unwrap();
    lock.execute_batch("BEGIN IMMEDIATE").unwrap();
    store.close().unwrap();
    wait(&mut store, |s| s.health() == Health::Failed);
    assert_eq!(store.status(&id), Some(CommitState::Unknown));
    lock.execute_batch("ROLLBACK").unwrap();
    for _ in 0..100 {
        store.poll();
        thread::sleep(Duration::from_millis(2));
    }
    assert_eq!(
        store.health(),
        Health::Failed,
        "late close must not overwrite storage failure"
    );
    assert_eq!(
        lock.query_row("SELECT dirty FROM meta WHERE id=1", [], |r| r
            .get::<_, i64>(0))
            .unwrap(),
        1
    );
    assert_eq!(
        lock.query_row("SELECT state FROM commits WHERE id=?1", [&id], |r| r
            .get::<_, String>(0))
            .unwrap(),
        "admitted"
    );
}
