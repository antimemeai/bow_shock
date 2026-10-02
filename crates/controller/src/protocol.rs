use bow_shock_evidence::{Batch, CommitState, Health, PublicationGuard, Review};
use serde::de::{MapAccess, Visitor, value::MapAccessDeserializer};
use serde::{Deserialize, Serialize};
use std::fmt;

pub const VERSION: u32 = 1;
#[derive(Deserialize)]
#[serde(tag = "op", rename_all = "snake_case", deny_unknown_fields)]
pub enum Request {
    Initialize {
        version: u32,
        run_id: String,
    },
    Ping {
        version: u32,
        id: u64,
    },
    StopAll {
        version: u32,
        id: u64,
    },
    Shutdown {
        version: u32,
        id: u64,
    },
    TableScope {
        version: u32,
        id: u64,
        origin: String,
    },
    TableStage {
        version: u32,
        id: u64,
        batch: Batch,
    },
    TableRevise {
        version: u32,
        id: u64,
        staging_id: String,
        batch: Batch,
    },
    TableReview {
        version: u32,
        id: u64,
        staging_id: String,
        retention_ms: u64,
    },
    TableApprove {
        version: u32,
        id: u64,
        review: Review,
    },
    TableCommit {
        version: u32,
        id: u64,
        approval_id: String,
    },
    TableStatus {
        version: u32,
        id: u64,
        commit_id: Option<String>,
    },
    TableList {
        version: u32,
        id: u64,
    },
    TableRead {
        version: u32,
        id: u64,
        commit_id: String,
    },
    TableDelete {
        version: u32,
        id: u64,
        commit_id: String,
    },
    TableClose {
        version: u32,
        id: u64,
    },
    AgentMetadata {
        version: u32,
        id: u64,
    },
    AgentStart {
        version: u32,
        id: u64,
        review: Review,
        candidate_ids: Vec<String>,
        objective: String,
        ttl_ms: u64,
    },
    AgentStatus {
        version: u32,
        id: u64,
        task_id: Option<String>,
    },
    AgentCancel {
        version: u32,
        id: u64,
        task_id: String,
    },
}
struct ObjectRequest(Request);
impl<'de> Deserialize<'de> for ObjectRequest {
    fn deserialize<D: serde::Deserializer<'de>>(deserializer: D) -> Result<Self, D::Error> {
        struct ObjectVisitor;
        impl<'de> Visitor<'de> for ObjectVisitor {
            type Value = ObjectRequest;
            fn expecting(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
                formatter.write_str("a closed request object")
            }
            fn visit_map<M: MapAccess<'de>>(self, map: M) -> Result<Self::Value, M::Error> {
                Request::deserialize(MapAccessDeserializer::new(map)).map(ObjectRequest)
            }
        }
        deserializer.deserialize_map(ObjectVisitor)
    }
}
pub fn decode(frame: &[u8]) -> Result<Request, ()> {
    // Reject positional struct/enum representations at every nested boundary.
    // Deserialize the original bytes afterward to retain duplicate-key evidence.
    let shape: serde_json::Value = serde_json::from_slice(frame).map_err(|_| ())?;
    if !shape.is_object() {
        return Err(());
    }
    if let Some(batch) = shape.get("batch") {
        batch_shape(batch)?;
    }
    if let Some(review) = shape.get("review")
        && !review.is_object()
    {
        return Err(());
    }
    serde_json::from_slice::<ObjectRequest>(frame)
        .map(|ObjectRequest(r)| r)
        .map_err(|_| ())
}
fn batch_shape(batch: &serde_json::Value) -> Result<(), ()> {
    if !batch.is_object() {
        return Err(());
    }
    let rows = batch.get("rows").and_then(|r| r.as_array()).ok_or(())?;
    for row in rows {
        if !row.is_object() {
            return Err(());
        }
        for field in row.get("fields").and_then(|f| f.as_array()).ok_or(())? {
            if !field.is_object() || !field.get("state").is_some_and(|s| s.is_object()) {
                return Err(());
            }
            let source = field.get("source").ok_or(())?;
            if !source.is_object()
                || source.get("node_id").is_none()
                || !source.get("observation").is_some_and(|o| o.is_object())
            {
                return Err(());
            }
        }
    }
    Ok(())
}
impl Request {
    pub fn version(&self) -> u32 {
        match self {
            Self::Initialize { version, .. }
            | Self::Ping { version, .. }
            | Self::StopAll { version, .. }
            | Self::Shutdown { version, .. }
            | Self::TableScope { version, .. }
            | Self::TableStage { version, .. }
            | Self::TableRevise { version, .. }
            | Self::TableReview { version, .. }
            | Self::TableApprove { version, .. }
            | Self::TableCommit { version, .. }
            | Self::TableStatus { version, .. }
            | Self::TableList { version, .. }
            | Self::TableRead { version, .. }
            | Self::TableDelete { version, .. }
            | Self::TableClose { version, .. }
            | Self::AgentMetadata { version, .. }
            | Self::AgentStart { version, .. }
            | Self::AgentStatus { version, .. }
            | Self::AgentCancel { version, .. } => *version,
        }
    }
    pub fn id(&self) -> Option<u64> {
        match self {
            Self::Initialize { .. } => None,
            Self::Ping { id, .. }
            | Self::StopAll { id, .. }
            | Self::Shutdown { id, .. }
            | Self::TableScope { id, .. }
            | Self::TableStage { id, .. }
            | Self::TableRevise { id, .. }
            | Self::TableReview { id, .. }
            | Self::TableApprove { id, .. }
            | Self::TableCommit { id, .. }
            | Self::TableStatus { id, .. }
            | Self::TableList { id, .. }
            | Self::TableRead { id, .. }
            | Self::TableDelete { id, .. }
            | Self::TableClose { id, .. }
            | Self::AgentMetadata { id, .. }
            | Self::AgentStart { id, .. }
            | Self::AgentStatus { id, .. }
            | Self::AgentCancel { id, .. } => Some(*id),
        }
    }
}
#[derive(Serialize)]
pub struct BootstrapReply<'a> {
    pub version: u32,
    pub op: &'static str,
    pub run_id: &'a str,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub id: Option<u64>,
    pub stop_generation: u64,
    pub active_powers: [(); 0],
}
#[derive(Serialize)]
pub struct ErrorReply {
    pub version: u32,
    pub op: &'static str,
    pub code: &'static str,
}
#[derive(Serialize)]
#[serde(tag = "op", rename_all = "snake_case")]
pub enum TablePayload {
    AgentMetadata {
        state: &'static str,
        descriptor: Option<crate::agent::Descriptor>,
    },
    AgentStarted {
        task_id: String,
        publication_guard: PublicationGuard,
        candidate_ids: Vec<String>,
    },
    AgentStatus {
        #[serde(flatten)]
        status: crate::agent::Status,
    },
    AgentCanceled {
        task_id: String,
        export_disposition: crate::agent::Disclosure,
    },
    AgentError {
        code: &'static str,
    },
    #[serde(rename = "table_scoped")]
    Scoped,
    #[serde(rename = "table_staged")]
    Staged {
        staging_id: String,
    },
    #[serde(rename = "table_revised")]
    Revised {
        staging_id: String,
    },
    #[serde(rename = "table_reviewed")]
    Reviewed {
        review: Review,
        publication_guard: PublicationGuard,
    },
    #[serde(rename = "table_approved")]
    Approved {
        approval_id: String,
    },
    #[serde(rename = "table_committed")]
    Committed {
        commit_id: String,
    },
    #[serde(rename = "table_status")]
    Status {
        health: Health,
        state: Option<CommitState>,
    },
    #[serde(rename = "table_listed")]
    Listed {
        commit_ids: Vec<String>,
        publication_guard: PublicationGuard,
    },
    #[serde(rename = "table_read")]
    Read {
        batch: Batch,
        publication_guard: PublicationGuard,
    },
    #[serde(rename = "table_deleted")]
    Deleted {
        commit_id: String,
    },
    #[serde(rename = "table_closed")]
    Closed,
    #[serde(rename = "table_error")]
    Error {
        code: &'static str,
    },
}
#[derive(Serialize)]
pub struct TableReply<'a> {
    pub version: u32,
    pub run_id: &'a str,
    pub id: u64,
    pub stop_generation: u64,
    #[serde(flatten)]
    pub payload: TablePayload,
}
pub struct State {
    pub run_id: Option<String>,
    last_id: u64,
    pub generation: u64,
}
impl State {
    pub fn new() -> Self {
        Self {
            run_id: None,
            last_id: 0,
            generation: 0,
        }
    }
    pub fn accept(&mut self, r: &Request) -> Result<(), &'static str> {
        if r.version() != VERSION {
            return Err("unsupported_version");
        }
        if let Request::Initialize { run_id, .. } = r {
            if self.run_id.is_some() {
                return Err("already_initialized");
            }
            if run_id.is_empty()
                || run_id.len() > 128
                || !run_id
                    .bytes()
                    .all(|b| b.is_ascii_alphanumeric() || matches!(b, b'-' | b'_' | b'.'))
            {
                return Err("invalid_run_id");
            }
            self.run_id = Some(run_id.clone());
            return Ok(());
        }
        if self.run_id.is_none() {
            return Err("not_initialized");
        }
        let id = r.id().expect("post-initialize identity");
        if id == 0 {
            return Err("invalid_request_id");
        }
        if id <= self.last_id {
            return Err("stale_request_id");
        }
        self.last_id = id;
        if matches!(r, Request::StopAll { .. }) {
            self.generation = self.generation.checked_add(1).ok_or("counter_exhausted")?;
        }
        Ok(())
    }
    pub fn bootstrap(&self, op: &'static str, id: Option<u64>) -> Vec<u8> {
        serde_json::to_vec(&BootstrapReply {
            version: VERSION,
            op,
            run_id: self.run_id.as_deref().expect("initialized"),
            id,
            stop_generation: self.generation,
            active_powers: [],
        })
        .expect("closed bootstrap serialization")
    }
    pub fn table(&self, id: u64, payload: TablePayload) -> Vec<u8> {
        // serde_json's default Map is sorted. Native Foundation can roundtrip
        // this canonical object without interpreting a different duplicate key.
        let value = serde_json::to_value(TableReply {
            version: VERSION,
            run_id: self.run_id.as_deref().expect("initialized"),
            id,
            stop_generation: self.generation,
            payload,
        })
        .expect("closed table serialization");
        serde_json::to_vec(&value).expect("canonical table serialization")
    }
}
