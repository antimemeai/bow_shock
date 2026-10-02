use crate::{Error, Result};
use serde::{Deserialize, Serialize};
use std::{
    io::Read,
    path::Path,
    process::{Child, Command, Stdio},
    sync::{
        Arc,
        atomic::{AtomicBool, AtomicUsize, Ordering},
    },
    thread,
    time::{Duration, Instant, SystemTime},
};

/// Shared lifetime of the process's owned clock queries, including SQLite's.
/// Cancellation never waits. Terminal callers must await quiescence before
/// exiting; cancelling denies every later spawn on this owner.
#[derive(Clone, Default)]
pub struct ClockOwner(Arc<QueryLifetime>);
#[derive(Default)]
struct QueryLifetime {
    cancelled: AtomicBool,
    active: AtomicUsize,
}
struct Activity(ClockOwner);
impl Drop for Activity {
    fn drop(&mut self) {
        self.0.0.active.fetch_sub(1, Ordering::SeqCst);
    }
}
struct OwnedChild(Child);
impl std::ops::Deref for OwnedChild {
    type Target = Child;
    fn deref(&self) -> &Child {
        &self.0
    }
}
impl std::ops::DerefMut for OwnedChild {
    fn deref_mut(&mut self) -> &mut Child {
        &mut self.0
    }
}
impl Drop for OwnedChild {
    fn drop(&mut self) {
        loop {
            if matches!(self.0.try_wait(), Ok(Some(_))) {
                return;
            }
            let _ = self.0.kill();
            if self.0.wait().is_ok() {
                return;
            }
            // Keep the activity registered until actual reap. An OS cleanup
            // error cannot be converted into quiescence and an orphaning exit.
            thread::sleep(Duration::from_millis(1));
        }
    }
}
impl ClockOwner {
    pub fn cancel(&self) {
        self.0.cancelled.store(true, Ordering::SeqCst);
    }
    pub fn is_quiescent(&self) -> bool {
        self.0.active.load(Ordering::SeqCst) == 0
    }
    fn cancelled(&self) -> bool {
        self.0.cancelled.load(Ordering::SeqCst)
    }
    /// Blocking IO only on a dedicated worker. Original owned producer must not
    /// fork descendants retaining stdout. Forced process death bypasses cleanup.
    pub fn query(&self, probe: &Path) -> Result<ClockWitness> {
        self.0.active.fetch_add(1, Ordering::SeqCst);
        let _activity = Activity(self.clone());
        if self.cancelled() {
            return Err(Error("native clock owner cancelled".into()));
        }
        query_owned(probe, self)
    }
}

/// Actual native boot identity and scaled mach_continuous_time, from a trusted
/// parent/helper. Neither page content nor a model may supply this value.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ClockWitness {
    pub boot_id: String,
    pub continuous_ns: u64,
}

impl ClockWitness {
    pub(crate) fn validate(&self) -> Result<()> {
        let bytes = self.boot_id.as_bytes();
        if bytes.len() != 36
            || !bytes.iter().enumerate().all(|(i, b)| {
                if [8, 13, 18, 23].contains(&i) {
                    *b == b'-'
                } else {
                    b.is_ascii_hexdigit()
                }
            })
            || self.continuous_ns == 0
            || self.continuous_ns > i64::MAX as u64
        {
            return Err(Error("invalid native boot/continuous witness".into()));
        }
        Ok(())
    }
    pub(crate) fn deadline(&self, millis: u64) -> Result<u64> {
        self.continuous_ns
            .checked_add(
                millis
                    .checked_mul(1_000_000)
                    .ok_or_else(|| Error("deadline integer limit".into()))?,
            )
            .filter(|n| *n <= i64::MAX as u64)
            .ok_or_else(|| Error("deadline integer limit".into()))
    }
}

/// Blocking query for the SQLite worker or a dedicated controller clock worker,
/// never the authority caller. The fixed
/// executable path is host configuration, not a protocol/model command field.
/// Query again after acquiring the DB lock and before each irreversible write.
pub fn query(probe: &Path) -> Result<ClockWitness> {
    ClockOwner::default().query(probe)
}
fn query_owned(probe: &Path, owner: &ClockOwner) -> Result<ClockWitness> {
    let mut child = OwnedChild(
        Command::new(probe)
            .stdin(Stdio::null())
            .stdout(Stdio::piped())
            .stderr(Stdio::null())
            .spawn()
            .map_err(|e| Error(format!("native clock unavailable: {e}")))?,
    );
    let mono = Instant::now();
    let wall = SystemTime::now();
    let status = loop {
        if owner.cancelled() {
            return Err(Error("native clock owner cancelled".into()));
        }
        match child.try_wait() {
            Ok(Some(status)) => break status,
            Ok(None) => {}
            Err(error) => {
                let _ = child.kill();
                let _ = child.wait();
                return Err(Error(error.to_string()));
            }
        }
        if mono.elapsed() > Duration::from_millis(500)
            || wall
                .elapsed()
                .map_or(true, |age| age > Duration::from_millis(500))
        {
            let _ = child.kill();
            let _ = child.wait();
            return Err(Error(
                "native clock query timeout/uncertain freshness".into(),
            ));
        }
        thread::sleep(Duration::from_millis(1));
    };
    if !status.success()
        || mono.elapsed() > Duration::from_millis(500)
        || wall
            .elapsed()
            .map_or(true, |age| age > Duration::from_millis(500))
    {
        return Err(Error("native clock failed/uncertain freshness".into()));
    }
    let mut output = Vec::new();
    child
        .stdout
        .take()
        .expect("owned stdout")
        .take(1025)
        .read_to_end(&mut output)
        .map_err(|e| Error(e.to_string()))?;
    if output.len() > 1024 {
        return Err(Error("native clock output limit".into()));
    }
    let witness: ClockWitness =
        serde_json::from_slice(&output).map_err(|e| Error(e.to_string()))?;
    witness.validate()?;
    Ok(witness)
}
