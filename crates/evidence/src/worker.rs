use crate::{ClockOwner, ClockWitness, MAX_BATCH_BYTES, MAX_COMMITS, Reviewed};
use rusqlite::{Connection, OptionalExtension, TransactionBehavior, params};
use std::{
    fs::{File, OpenOptions},
    path::PathBuf,
    sync::{
        Arc,
        atomic::{AtomicBool, Ordering},
        mpsc::{Receiver, SyncSender},
    },
    time::Duration,
};

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) enum Work {
    Open,
    Prepare,
    Admit,
    Write,
    Delete,
    Recover,
    Close,
}
pub(crate) struct Job {
    pub work: Work,
    pub id: String,
    pub stage: String,
    pub version: u64,
    pub content: String,
    pub fence: Arc<AtomicBool>,
    pub boot_id: Option<String>,
    pub expires_ns: Option<u64>,
}
pub(crate) struct Completion {
    pub id: String,
    pub work: Work,
    pub result: Result<(), String>,
    pub quarantined: bool,
    pub restored: Vec<Restored>,
}
pub(crate) struct Restored {
    pub id: String,
    pub stage: String,
    pub version: u64,
    pub content: String,
    pub boot_id: String,
    pub expires_ns: u64,
}

pub(crate) fn run(
    path: PathBuf,
    run_id: String,
    native: Option<(ClockWitness, PathBuf, ClockOwner)>,
    rx: Receiver<Job>,
    tx: SyncSender<Completion>,
) {
    let opened = open(path, &run_id, native.as_ref());
    let (mut conn, owner, quarantined, restored) = match opened {
        Ok(value) => value,
        Err(error) => {
            let _ = tx.send(Completion {
                id: String::new(),
                work: Work::Open,
                result: Err(error),
                quarantined: true,
                restored: Vec::new(),
            });
            return;
        }
    };
    if tx
        .send(Completion {
            id: String::new(),
            work: Work::Open,
            result: Ok(()),
            quarantined,
            restored,
        })
        .is_err()
    {
        return;
    }
    while let Ok(job) = rx.recv() {
        let result = execute(&mut conn, &job, &run_id, native.as_ref()).map_err(|e| e.to_string());
        let close = job.work == Work::Close;
        if close {
            // All accepted jobs precede Close; release actual writer/ownership
            // before acknowledging clean closure to a replacement caller.
            drop(conn);
            drop(owner);
            let _ = tx.send(Completion {
                id: job.id,
                work: job.work,
                result,
                quarantined: false,
                restored: Vec::new(),
            });
            return;
        }
        if tx
            .send(Completion {
                id: job.id,
                work: job.work,
                result,
                quarantined: false,
                restored: Vec::new(),
            })
            .is_err()
        {
            return;
        }
    }
    // Dropped/crashed authority never writes a clean marker.
}

fn open(
    path: PathBuf,
    run_id: &str,
    native: Option<&(ClockWitness, PathBuf, ClockOwner)>,
) -> Result<(Connection, File, bool, Vec<Restored>), String> {
    // Private application-owned path only. Canonicalize its parent to prevent
    // a spelling/symlink alias from choosing another ownership file.
    let path = if path.exists() {
        path.canonicalize()
    } else {
        let parent = path
            .parent()
            .filter(|p| !p.as_os_str().is_empty())
            .unwrap_or(std::path::Path::new("."));
        parent
            .canonicalize()
            .map(|p| p.join(path.file_name().unwrap_or_default()))
    }
    .map_err(|e| e.to_string())?;
    let mut owner_path = path.as_os_str().to_os_string();
    owner_path.push(".owner");
    let mut options = OpenOptions::new();
    options.create(true).truncate(false).read(true).write(true);
    #[cfg(unix)]
    {
        use std::os::unix::fs::OpenOptionsExt;
        options.mode(0o600);
    }
    let owner = options.open(owner_path).map_err(|e| e.to_string())?;
    owner
        .try_lock()
        .map_err(|e| format!("evidence store already owned or lock unavailable: {e}"))?;
    // Never unlink the lock file: contenders must lock the same live inode.
    let mut conn = Connection::open(&path).map_err(|e| e.to_string())?;
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        std::fs::set_permissions(&path, std::fs::Permissions::from_mode(0o600))
            .map_err(|e| e.to_string())?;
    }
    conn.busy_timeout(Duration::from_secs(2))
        .map_err(|e| e.to_string())?;
    let version: i64 = conn
        .query_row("PRAGMA user_version", [], |r| r.get(0))
        .map_err(|e| e.to_string())?;
    if version != 0 && version != 1 && version != 2 {
        return Err("unsupported evidence schema version".into());
    }
    let mode: String = conn
        .query_row("PRAGMA journal_mode=WAL", [], |r| r.get(0))
        .map_err(|e| e.to_string())?;
    if mode != "wal" {
        return Err("evidence requires supported local WAL filesystem".into());
    }
    conn.execute_batch("PRAGMA synchronous=FULL; PRAGMA foreign_keys=ON; BEGIN IMMEDIATE;
        CREATE TABLE IF NOT EXISTS meta (id INTEGER PRIMARY KEY CHECK(id=1), dirty INTEGER NOT NULL, run_id TEXT NOT NULL);
        CREATE TABLE IF NOT EXISTS commits (id TEXT PRIMARY KEY, staging_id TEXT NOT NULL, version INTEGER NOT NULL, review TEXT NOT NULL, state TEXT NOT NULL);
        CREATE TABLE IF NOT EXISTS rows (commit_id TEXT NOT NULL REFERENCES commits(id) ON DELETE CASCADE, row_index INTEGER NOT NULL, payload TEXT NOT NULL, PRIMARY KEY(commit_id,row_index));
        CREATE TABLE IF NOT EXISTS deletions (id TEXT PRIMARY KEY);
        PRAGMA user_version=2;").map_err(|e| e.to_string())?;
    if version < 2 {
        conn.execute_batch("ALTER TABLE meta ADD COLUMN boot_id TEXT; ALTER TABLE meta ADD COLUMN clock_ns INTEGER;
            ALTER TABLE commits ADD COLUMN boot_id TEXT; ALTER TABLE commits ADD COLUMN expires_ns INTEGER;").map_err(|e| e.to_string())?;
    }
    conn.execute_batch("COMMIT;").map_err(|e| e.to_string())?;
    let transaction = conn
        .transaction_with_behavior(TransactionBehavior::Immediate)
        .map_err(|e| e.to_string())?;
    let dirty: Option<i64> = transaction
        .query_row("SELECT dirty FROM meta WHERE id=1", [], |r| r.get(0))
        .optional()
        .map_err(|e| e.to_string())?;
    let records: i64 = transaction
        .query_row("SELECT count(*) FROM commits", [], |r| r.get(0))
        .map_err(|e| e.to_string())?;
    let fences: i64 = transaction
        .query_row("SELECT count(*) FROM deletions", [], |r| r.get(0))
        .map_err(|e| e.to_string())?;
    let actual = native
        .map(|(expected, probe, owner)| {
            let current = owner.query(probe)?;
            if current.boot_id != expected.boot_id || current.continuous_ns < expected.continuous_ns
            {
                return Err(crate::Error("native startup boot/clock mismatch".into()));
            }
            Ok(current)
        })
        .transpose()
        .map_err(|e| e.to_string())?;
    let stored_clock: Option<(Option<String>, Option<i64>)> = transaction
        .query_row("SELECT boot_id,clock_ns FROM meta WHERE id=1", [], |r| {
            Ok((r.get(0)?, r.get(1)?))
        })
        .optional()
        .map_err(|e| e.to_string())?;
    let compatible = match (&actual, &stored_clock) {
        (Some(now), Some((Some(boot), Some(last)))) => {
            boot == &now.boot_id && *last > 0 && now.continuous_ns >= *last as u64
        }
        _ => records == 0,
    };
    let unresolved: i64 = transaction.query_row("SELECT count(*) FROM commits WHERE state!='committed' OR boot_id IS NULL OR expires_ns IS NULL", [], |r| r.get(0)).map_err(|e| e.to_string())?;
    let quarantined = dirty == Some(1)
        || fences != 0
        || records > MAX_COMMITS as i64
        || (records != 0 && (!compatible || unresolved != 0));
    let mut restored = Vec::new();
    if !quarantined && records != 0 {
        let now = actual
            .as_ref()
            .ok_or("retained results require native witness")?;
        // Required expiry is actual native time; never infer it from wall time.
        transaction
            .execute(
                "DELETE FROM commits WHERE boot_id=?1 AND expires_ns<=?2",
                params![now.boot_id, now.continuous_ns as i64],
            )
            .map_err(|e| e.to_string())?;
        let mut stmt = transaction
            .prepare("SELECT id,staging_id,version,review,boot_id,expires_ns FROM commits")
            .map_err(|e| e.to_string())?;
        let saved = stmt
            .query_map([], |r| {
                Ok(Restored {
                    id: r.get(0)?,
                    stage: r.get(1)?,
                    version: r.get::<_, i64>(2)? as u64,
                    content: r.get(3)?,
                    boot_id: r.get(4)?,
                    expires_ns: r.get::<_, i64>(5)? as u64,
                })
            })
            .map_err(|e| e.to_string())?;
        for entry in saved {
            let entry = entry.map_err(|e| e.to_string())?;
            if entry.content.len() > MAX_BATCH_BYTES
                || entry.boot_id != now.boot_id
                || entry.expires_ns <= now.continuous_ns
                || entry.expires_ns > i64::MAX as u64
                || entry.version == 0
            {
                return Err("invalid retained commit/clock identity".into());
            }
            let review: Reviewed =
                serde_json::from_str(&entry.content).map_err(|e| e.to_string())?;
            if review.batch.rows.is_empty()
                || review.batch.rows.len() > 16
                || review.retention_ms == 0
                || review.retention_ms > crate::MAX_RETENTION_MS
            {
                return Err("invalid saved rows".into());
            }
            let mut rows = transaction
                .prepare("SELECT payload FROM rows WHERE commit_id=?1 ORDER BY row_index")
                .map_err(|e| e.to_string())?;
            let payloads: Vec<String> = rows
                .query_map([&entry.id], |r| r.get(0))
                .map_err(|e| e.to_string())?
                .collect::<rusqlite::Result<_>>()
                .map_err(|e| e.to_string())?;
            let expected: Vec<String> = review
                .batch
                .rows
                .iter()
                .map(serde_json::to_string)
                .collect::<Result<_, _>>()
                .map_err(|e| e.to_string())?;
            if payloads != expected {
                return Err("saved rows disagree with exact immutable result".into());
            }
            restored.push(entry);
        }
    }
    let final_clock = native
        .map(|(_, probe, owner)| owner.query(probe))
        .transpose()
        .map_err(|e| e.to_string())?;
    if let (Some(first), Some(last)) = (&actual, &final_clock) {
        if first.boot_id != last.boot_id || last.continuous_ns < first.continuous_ns {
            return Err("startup clock discontinuity".into());
        }
        if !quarantined {
            transaction
                .execute(
                    "DELETE FROM commits WHERE boot_id=?1 AND expires_ns<=?2",
                    params![last.boot_id, last.continuous_ns as i64],
                )
                .map_err(|e| e.to_string())?;
            restored.retain(|r| r.expires_ns > last.continuous_ns);
        }
    }
    transaction.execute("INSERT INTO meta(id,dirty,run_id,boot_id,clock_ns) VALUES(1,1,?1,?2,?3)
        ON CONFLICT(id) DO UPDATE SET dirty=1,run_id=excluded.run_id,boot_id=excluded.boot_id,clock_ns=excluded.clock_ns",
        params![run_id, final_clock.as_ref().map(|c| &c.boot_id), final_clock.as_ref().map(|c| c.continuous_ns as i64)]).map_err(|e| e.to_string())?;
    transaction.commit().map_err(|e| e.to_string())?;
    Ok((conn, owner, quarantined, restored))
}

fn execute(
    conn: &mut Connection,
    job: &Job,
    run_id: &str,
    native: Option<&(ClockWitness, PathBuf, ClockOwner)>,
) -> rusqlite::Result<()> {
    if job.work == Work::Delete {
        // Durable processed intent precedes actual purge. If the second
        // transaction fails, dirty restart/fence keeps the partition denied.
        conn.execute("INSERT OR IGNORE INTO deletions(id) VALUES(?1)", [&job.id])?;
        let tx = conn.transaction_with_behavior(TransactionBehavior::Immediate)?;
        tx.execute("DELETE FROM commits WHERE id=?1", [&job.id])?;
        tx.execute("DELETE FROM deletions WHERE id=?1", [&job.id])?;
        return tx.commit();
    }
    let tx = conn.transaction_with_behavior(TransactionBehavior::Immediate)?;
    if !native_gate(&tx, job, native)? {
        return Ok(());
    }
    match job.work {
        Work::Prepare | Work::Admit | Work::Write if job.fence.load(Ordering::SeqCst) => {
            return Ok(());
        }
        Work::Prepare => {
            let version = i64::try_from(job.version).map_err(|_| rusqlite::Error::InvalidQuery)?;
            tx.execute("INSERT INTO commits(id,staging_id,version,review,state,boot_id,expires_ns) VALUES(?1,?2,?3,?4,'prepared',?5,?6)",
                params![job.id, job.stage, version, job.content, job.boot_id, job.expires_ns.map(|n| n as i64)])?;
        }
        Work::Admit => {
            let changed = tx.execute("UPDATE commits SET state='admitted' WHERE id=?1 AND review=?2 AND state='prepared'", params![job.id, job.content])?;
            if changed != 1 {
                return Err(rusqlite::Error::QueryReturnedNoRows);
            }
        }
        Work::Write => {
            let review: String = tx.query_row(
                "SELECT review FROM commits WHERE id=?1 AND state='admitted'",
                [&job.id],
                |r| r.get(0),
            )?;
            if review != job.content {
                return Err(rusqlite::Error::InvalidQuery);
            }
            let reviewed: Reviewed =
                serde_json::from_str(&review).map_err(|_| rusqlite::Error::InvalidQuery)?;
            for (index, row) in reviewed.batch.rows.iter().enumerate() {
                let index = i64::try_from(index).map_err(|_| rusqlite::Error::InvalidQuery)?;
                let payload =
                    serde_json::to_string(row).map_err(|_| rusqlite::Error::InvalidQuery)?;
                tx.execute(
                    "INSERT INTO rows(commit_id,row_index,payload) VALUES(?1,?2,?3)",
                    params![job.id, index, payload],
                )?;
            }
            tx.execute(
                "UPDATE commits SET state='committed' WHERE id=?1",
                [&job.id],
            )?;
            if job.fence.load(Ordering::SeqCst) {
                return Ok(());
            }
        }
        Work::Recover => {
            tx.execute_batch("DELETE FROM rows; DELETE FROM commits; DELETE FROM deletions;")?;
            tx.execute("UPDATE meta SET dirty=1,run_id=?1 WHERE id=1", [run_id])?;
        }
        Work::Close => {
            let unresolved: i64 = tx.query_row(
                "SELECT count(*) FROM commits WHERE state!='committed'",
                [],
                |r| r.get(0),
            )?;
            let fences: i64 = tx.query_row("SELECT count(*) FROM deletions", [], |r| r.get(0))?;
            if unresolved != 0 || fences != 0 {
                return Err(rusqlite::Error::InvalidQuery);
            }
            tx.execute("UPDATE meta SET dirty=0 WHERE id=1", [])?;
        }
        Work::Open | Work::Delete => return Err(rusqlite::Error::InvalidQuery),
    }
    if !native_gate(&tx, job, native)? {
        return Ok(());
    }
    tx.commit()
}

fn native_gate(
    tx: &rusqlite::Transaction<'_>,
    job: &Job,
    native: Option<&(ClockWitness, PathBuf, ClockOwner)>,
) -> rusqlite::Result<bool> {
    let Some((expected, probe, owner)) = native else {
        return Ok(true);
    };
    let actual = owner
        .query(probe)
        .map_err(|e| rusqlite::Error::InvalidParameterName(e.to_string()))?;
    if actual.boot_id != expected.boot_id
        || job.boot_id.as_ref() != Some(&actual.boot_id)
        || actual.continuous_ns < expected.continuous_ns
    {
        return Err(rusqlite::Error::InvalidQuery);
    }
    let last: Option<i64> =
        tx.query_row("SELECT clock_ns FROM meta WHERE id=1", [], |r| r.get(0))?;
    if last.is_some_and(|n| n < 0 || actual.continuous_ns < n as u64) {
        return Err(rusqlite::Error::InvalidQuery);
    }
    if job
        .expires_ns
        .is_some_and(|deadline| actual.continuous_ns >= deadline)
    {
        job.fence.store(true, Ordering::SeqCst);
        return Ok(false);
    }
    tx.execute(
        "UPDATE meta SET boot_id=?1,clock_ns=?2 WHERE id=1",
        params![actual.boot_id, actual.continuous_ns as i64],
    )?;
    Ok(true)
}
