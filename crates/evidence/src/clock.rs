use crate::{Error, Result};
use serde::{Deserialize, Serialize};
use std::{
    io::Read,
    path::Path,
    process::{Command, Stdio},
    thread,
    time::{Duration, Instant, SystemTime},
};

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

/// Runs only on the SQLite worker, never on the authority caller. The fixed
/// executable path is host configuration, not a protocol/model command field.
/// Query again after acquiring the DB lock and before each irreversible write.
pub(crate) fn query(probe: &Path) -> Result<ClockWitness> {
    let mut child = Command::new(probe)
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::null())
        .spawn()
        .map_err(|e| Error(format!("native clock unavailable: {e}")))?;
    let mono = Instant::now();
    let wall = SystemTime::now();
    let status = loop {
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
