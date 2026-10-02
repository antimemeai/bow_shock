//! One serialized authority; blocking pipes/probes/SQLite belong to workers.
use crate::protocol::{self, ErrorReply, Request, State, TablePayload, VERSION};
use bow_shock_controller_link::{FrameReader, FrameWriter, MAX_FRAME_BYTES};
use bow_shock_evidence::{
    Approval, Batch, ClockOwner, ClockWitness, FieldState, Health, Review, SourcePolicy, Store,
};
use std::{
    collections::{BTreeMap, VecDeque},
    io,
    path::PathBuf,
    sync::mpsc::{self, Receiver, SyncSender, TryRecvError},
    thread,
    time::{Duration, Instant, SystemTime},
};
const QUEUE: usize = 8;
const IO_TIMEOUT: Duration = Duration::from_secs(2);
const POLL_INTERVAL: Duration = Duration::from_millis(20);
const MAX_BATCH: usize = 16 * 1024;
const MAX_REVIEW: usize = 24 * 1024;
const MAX_RETENTION: u64 = 24 * 60 * 60 * 1000;

pub struct Config {
    db: PathBuf,
    probe: PathBuf,
    origin: String,
    agent: Option<crate::agent::Settings>,
}
pub fn configuration() -> Result<Option<Config>, ()> {
    let mut args = std::env::args_os().skip(1);
    let Some(first) = args.next() else {
        return Ok(None);
    };
    if first != "--table-db" {
        return Err(());
    }
    let db = PathBuf::from(args.next().ok_or(())?);
    if args.next().as_deref() != Some(std::ffi::OsStr::new("--clock-probe")) {
        return Err(());
    }
    let probe = PathBuf::from(args.next().ok_or(())?);
    if args.next().as_deref() != Some(std::ffi::OsStr::new("--owned-origin")) {
        return Err(());
    }
    let origin = args.next().ok_or(())?.into_string().map_err(|_| ())?;
    let agent = if let Some(flag) = args.next() {
        if flag != "--agent-executable" {
            return Err(());
        }
        let executable = PathBuf::from(args.next().ok_or(())?);
        let mut options = BTreeMap::new();
        while let Some(flag) = args.next() {
            let flag = flag.into_string().map_err(|_| ())?;
            if ![
                "--agent-cwd",
                "--agent-model",
                "--agent-provider",
                "--agent-home",
                "--agent-user-home",
                "--agent-account",
            ]
            .contains(&flag.as_str())
                || options.insert(flag, args.next().ok_or(())?).is_some()
            {
                return Err(());
            }
        }
        let cwd = PathBuf::from(options.remove("--agent-cwd").ok_or(())?);
        let home = PathBuf::from(options.remove("--agent-home").ok_or(())?);
        let user_home = PathBuf::from(options.remove("--agent-user-home").ok_or(())?);
        let model = options
            .remove("--agent-model")
            .ok_or(())?
            .into_string()
            .map_err(|_| ())?;
        let provider = options
            .remove("--agent-provider")
            .ok_or(())?
            .into_string()
            .map_err(|_| ())?;
        let account = options
            .remove("--agent-account")
            .map(|v| v.into_string().map_err(|_| ()))
            .transpose()?;
        if provider != "openai"
            || [&executable, &cwd, &home, &user_home]
                .iter()
                .any(|p| !p.is_absolute())
            || [Some(&model), Some(&provider), account.as_ref()]
                .iter()
                .flatten()
                .any(|v| v.is_empty() || v.len() > 128 || v.contains(['\n', '\r', '\0']))
        {
            return Err(());
        }
        Some(crate::agent::Settings {
            executable,
            cwd,
            home,
            user_home,
            model,
            provider,
            account,
        })
    } else {
        None
    };
    if origin.is_empty() || origin.len() > 128 || origin.contains(['\n', '\r', '\0']) {
        return Err(());
    }
    // Private application-owned paths, never supplied by incoming records.
    Ok(Some(Config {
        db,
        probe,
        origin,
        agent,
    }))
}
enum Incoming {
    Frame(Vec<u8>),
    Eof,
    Error,
}
fn io_workers() -> (Receiver<Incoming>, SyncSender<Vec<u8>>, Receiver<bool>) {
    let (tx, rx) = mpsc::sync_channel(QUEUE);
    thread::spawn(move || {
        let mut reader = FrameReader::new(io::stdin().lock());
        loop {
            let event = match reader.read_frame() {
                Ok(Some(bytes)) => Incoming::Frame(bytes),
                Ok(None) => Incoming::Eof,
                Err(_) => Incoming::Error,
            };
            let terminal = !matches!(event, Incoming::Frame(_));
            if tx.send(event).is_err() || terminal {
                return;
            }
        }
    });
    let (write_tx, write_rx) = mpsc::sync_channel::<Vec<u8>>(1);
    let (done_tx, done_rx) = mpsc::sync_channel(1);
    thread::spawn(move || {
        let mut writer = FrameWriter::new(io::stdout().lock());
        while let Ok(frame) = write_rx.recv() {
            let okay = writer.write_frame(&frame).is_ok();
            if done_tx.send(okay).is_err() || !okay {
                return;
            }
        }
    });
    (rx, write_tx, done_rx)
}
type ClockResult = Result<ClockWitness, bow_shock_evidence::Error>;
fn clock_worker(probe: PathBuf, owner: ClockOwner) -> (SyncSender<()>, Receiver<ClockResult>) {
    let (tx, rx) = mpsc::sync_channel(1);
    let (done_tx, done_rx) = mpsc::sync_channel(1);
    thread::spawn(move || {
        while rx.recv().is_ok() {
            if done_tx.send(owner.query(&probe)).is_err() {
                return;
            }
        }
    });
    (tx, done_rx)
}
struct Pending {
    request: Request,
    generation: u64,
}
enum Gate {
    Review(Review),
    Read(String),
    List,
    AgentStatus(String),
}
struct Outbound {
    bytes: Vec<u8>,
    id: u64,
    generation: u64,
    gate: Option<Gate>,
}
enum ClockTask {
    Open,
    Poll,
    Operation(Pending),
    Publication(Outbound),
}
struct Age {
    mono: Instant,
    wall: SystemTime,
}
impl Age {
    fn new() -> Self {
        Self {
            mono: Instant::now(),
            wall: SystemTime::now(),
        }
    }
    fn expired(&self, limit: Duration) -> bool {
        self.mono.elapsed() > limit || self.wall.elapsed().map_or(true, |d| d > limit)
    }
}
struct Actor {
    state: State,
    config: Option<Config>,
    store: Option<Store>,
    approvals: BTreeMap<String, Approval>,
    pending: VecDeque<Pending>,
    outgoing: VecDeque<Outbound>,
    clock: Option<(SyncSender<()>, Receiver<ClockResult>)>,
    clock_owner: ClockOwner,
    clock_task: Option<ClockTask>,
    clock_age: Option<Age>,
    writer_age: Option<Age>,
    open_needed: bool,
    closing: Option<u64>,
    finished: Option<bool>,
    last_poll: Instant,
    agent: crate::agent::Manager,
}
impl Actor {
    fn new(config: Option<Config>) -> Self {
        let clock_owner = ClockOwner::default();
        let clock = config
            .as_ref()
            .map(|c| clock_worker(c.probe.clone(), clock_owner.clone()));
        let agent = crate::agent::Manager::new(
            config.as_ref().and_then(|c| c.agent.clone()),
            config.as_ref().map(|c| c.probe.clone()).unwrap_or_default(),
            clock_owner.clone(),
        );
        Self {
            state: State::new(),
            config,
            store: None,
            approvals: BTreeMap::new(),
            pending: VecDeque::new(),
            outgoing: VecDeque::new(),
            clock,
            clock_owner,
            clock_task: None,
            clock_age: None,
            writer_age: None,
            open_needed: false,
            closing: None,
            finished: None,
            last_poll: Instant::now(),
            agent,
        }
    }
    fn enqueue(&mut self, bytes: Vec<u8>, id: u64, gate: Option<Gate>) -> Result<(), ()> {
        if bytes.len() > MAX_FRAME_BYTES || self.outgoing.len() >= QUEUE {
            return Err(());
        }
        self.outgoing.push_back(Outbound {
            bytes,
            id,
            generation: self.state.generation,
            gate,
        });
        Ok(())
    }
    fn table(&mut self, id: u64, payload: TablePayload, gate: Option<Gate>) -> Result<(), ()> {
        self.enqueue(self.state.table(id, payload), id, gate)
    }
    fn table_error(&mut self, id: u64, code: &'static str) -> Result<(), ()> {
        self.table(id, TablePayload::Error { code }, None)
    }
    fn reject(&mut self, code: &'static str) -> Result<(), ()> {
        self.agent.retire(crate::agent::TaskState::Canceled);
        if let Some(store) = &mut self.store {
            store.stop();
        }
        self.pending.clear();
        self.outgoing.retain(|out| out.gate.is_none());
        self.finished = Some(false);
        let bytes = serde_json::to_vec(&ErrorReply {
            version: VERSION,
            op: "error",
            code,
        })
        .map_err(|_| ())?;
        self.enqueue(bytes, 0, None)
    }
    fn incoming(&mut self, event: Incoming) -> Result<(), ()> {
        match event {
            Incoming::Eof => {
                self.agent.retire(crate::agent::TaskState::Canceled);
                if let Some(store) = &mut self.store {
                    if store.health() != Health::Closed {
                        store.stop();
                        self.finished = Some(false);
                    } else {
                        self.finished = Some(true);
                    }
                } else {
                    self.finished = Some(self.config.is_none());
                }
                Ok(())
            }
            Incoming::Error => self.reject("invalid_frame"),
            Incoming::Frame(bytes) => {
                let request = match protocol::decode(&bytes) {
                    Ok(r) => r,
                    Err(()) => return self.reject("invalid_message"),
                };
                if let Err(code) = self.state.accept(&request) {
                    return self.reject(code);
                }
                let id = request.id().unwrap_or(0);
                if matches!(
                    request,
                    Request::TableScope { .. }
                        | Request::TableRevise { .. }
                        | Request::TableApprove { .. }
                        | Request::TableClose { .. }
                ) {
                    self.agent.retire(crate::agent::TaskState::Canceled);
                }
                match request {
                    Request::Initialize { .. } => {
                        self.open_needed = self.config.is_some();
                        self.enqueue(self.state.bootstrap("initialized", None), 0, None)
                    }
                    Request::Ping { .. } => {
                        self.enqueue(self.state.bootstrap("pong", Some(id)), id, None)
                    }
                    Request::StopAll { .. } => {
                        self.agent.retire(crate::agent::TaskState::Canceled);
                        if let Some(s) = &mut self.store {
                            s.stop();
                        }
                        self.enqueue(self.state.bootstrap("stopped", Some(id)), id, None)
                    }
                    Request::Shutdown { .. } => {
                        self.agent.shutdown();
                        if self
                            .store
                            .as_ref()
                            .is_some_and(|s| s.health() != Health::Closed)
                            || (self.config.is_some() && self.store.is_none())
                        {
                            return self.reject("table_close_required");
                        }
                        self.finished = Some(true);
                        self.enqueue(self.state.bootstrap("shutdown", Some(id)), id, None)
                    }
                    Request::AgentMetadata { .. } => self.table(
                        id,
                        TablePayload::AgentMetadata {
                            state: self.agent.metadata_state,
                            descriptor: self.agent.descriptor.clone(),
                        },
                        None,
                    ),
                    Request::AgentCancel { task_id, .. } => {
                        if self
                            .agent
                            .task
                            .as_ref()
                            .is_none_or(|task| task.id != task_id)
                        {
                            return self.table(
                                id,
                                TablePayload::AgentError {
                                    code: "unknown_task",
                                },
                                None,
                            );
                        }
                        self.agent.retire(crate::agent::TaskState::Canceled);
                        self.table(
                            id,
                            TablePayload::AgentCanceled {
                                task_id,
                                export_disposition: self.agent.status().export_disposition,
                            },
                            None,
                        )
                    }
                    Request::AgentStatus { ref task_id, .. } => {
                        if task_id.as_ref().is_some_and(|id| {
                            self.agent.task.as_ref().is_none_or(|task| task.id != *id)
                        }) {
                            return self.table(
                                id,
                                TablePayload::AgentError {
                                    code: "unknown_task",
                                },
                                None,
                            );
                        }
                        let status = self.agent.status();
                        let gate = status
                            .publication_guard
                            .as_ref()
                            .and(status.task_id.as_ref())
                            .map(|task_id| Gate::AgentStatus(task_id.clone()));
                        self.table(id, TablePayload::AgentStatus { status }, gate)
                    }
                    request => {
                        if self.config.is_none() {
                            return self.reject("table_mode_required");
                        }
                        if self.pending.len() >= QUEUE {
                            return Err(());
                        }
                        self.pending.push_back(Pending {
                            request,
                            generation: self.state.generation,
                        });
                        Ok(())
                    }
                }
            }
        }
    }
    fn execute(&mut self, pending: Pending, witness: ClockWitness) -> Result<(), ()> {
        let id = pending.request.id().expect("table request");
        if pending.generation != self.state.generation {
            return self.table_error(id, "stopped");
        }
        if let Request::AgentStart {
            review,
            candidate_ids,
            objective,
            ttl_ms,
            ..
        } = pending.request
        {
            return self.start_agent(id, review, candidate_ids, objective, ttl_ms, witness);
        }
        let Some(store) = &mut self.store else {
            return self.table_error(id, "not_ready");
        };
        let mut gate = None;
        let result: Result<Option<TablePayload>, bow_shock_evidence::Error> = (|| {
            Ok(Some(match pending.request {
                Request::TableScope { origin, .. } => {
                    if origin != self.config.as_ref().expect("mode").origin {
                        return Err(bow_shock_evidence::Error("scope".into()));
                    }
                    store.set_origins_at(vec![origin], witness)?;
                    TablePayload::Scoped
                }
                Request::TableStage { batch, .. } => {
                    native_batch(&batch, &witness)?;
                    let id = store.stage_at(
                        batch,
                        SourcePolicy {
                            allow_retained_rows: true,
                            max_retention_ms: MAX_RETENTION,
                            session_ttl_ms: MAX_RETENTION,
                        },
                        witness,
                    )?;
                    TablePayload::Staged { staging_id: id }
                }
                Request::TableRevise {
                    staging_id, batch, ..
                } => {
                    native_batch(&batch, &witness)?;
                    store.revise_at(&staging_id, batch, witness)?;
                    TablePayload::Revised { staging_id }
                }
                Request::TableReview {
                    staging_id,
                    retention_ms,
                    ..
                } => {
                    let (review, publication_guard) =
                        store.review_guarded_at(&staging_id, retention_ms, witness)?;
                    if review.content.len() > MAX_REVIEW {
                        return Err(bow_shock_evidence::Error("review budget".into()));
                    }
                    gate = Some(Gate::Review(review.clone()));
                    TablePayload::Reviewed {
                        review,
                        publication_guard,
                    }
                }
                Request::TableApprove { review, .. } => {
                    if review.content.len() > MAX_REVIEW {
                        return Err(bow_shock_evidence::Error("review budget".into()));
                    }
                    let approval = store.approve_at(&review, witness)?;
                    // The private library Approval cannot be deserialized from the pipe.
                    let commit = approval.id().to_string();
                    self.approvals.entry(commit.clone()).or_insert(approval);
                    TablePayload::Approved {
                        approval_id: commit,
                    }
                }
                Request::TableCommit { approval_id, .. } => {
                    let a = self
                        .approvals
                        .get(&approval_id)
                        .ok_or_else(|| bow_shock_evidence::Error("unknown approval".into()))?;
                    TablePayload::Committed {
                        commit_id: store.commit_at(a, witness)?,
                    }
                }
                Request::TableStatus { commit_id, .. } => {
                    store.poll_at(witness)?;
                    self.last_poll = Instant::now();
                    TablePayload::Status {
                        health: store.health(),
                        state: commit_id.as_deref().and_then(|id| store.status(id)),
                    }
                }
                Request::TableList { .. } => {
                    let (ids, publication_guard) = store.committed_ids_guarded_at(witness)?;
                    gate = Some(Gate::List);
                    TablePayload::Listed {
                        commit_ids: ids,
                        publication_guard,
                    }
                }
                Request::TableRead { commit_id, .. } => {
                    let (batch, publication_guard) = store.read_guarded_at(&commit_id, witness)?;
                    gate = Some(Gate::Read(commit_id));
                    TablePayload::Read {
                        batch,
                        publication_guard,
                    }
                }
                Request::TableDelete { commit_id, .. } => {
                    store.update_clock(witness)?;
                    store.delete(&commit_id)?;
                    TablePayload::Deleted { commit_id }
                }
                Request::TableClose { .. } => {
                    if self.closing.is_some() {
                        return Err(bow_shock_evidence::Error("close pending".into()));
                    }
                    store.close_at(witness)?;
                    self.closing = Some(id);
                    return Ok(None);
                }
                _ => unreachable!("table dispatch"),
            }))
        })();
        match result {
            Ok(Some(payload)) => self.table(id, payload, gate),
            Ok(None) => Ok(()),
            Err(_) => self.table_error(id, "table_rejected"),
        }
    }
    fn publish(&mut self, mut out: Outbound, witness: ClockWitness) -> Result<Outbound, ()> {
        if out.generation != self.state.generation {
            out.bytes = self
                .state
                .table(out.id, TablePayload::Error { code: "stopped" });
            out.gate = None;
            return Ok(out);
        }
        if let Some(Gate::AgentStatus(task_id)) = &out.gate {
            if self
                .agent
                .task
                .as_ref()
                .is_none_or(|task| task.id != *task_id)
            {
                out.bytes = self.state.table(
                    out.id,
                    TablePayload::AgentError {
                        code: "unknown_task",
                    },
                );
                out.gate = None;
                return Ok(out);
            }
            self.check_agent(witness);
            out.bytes = self.state.table(
                out.id,
                TablePayload::AgentStatus {
                    status: self.agent.status(),
                },
            );
            out.gate = None;
            return Ok(out);
        }
        let store = self.store.as_mut().ok_or(())?;
        let result: Result<TablePayload, bow_shock_evidence::Error> =
            match out.gate.take().expect("publication gate") {
                Gate::Read(id) => {
                    store
                        .read_guarded_at(&id, witness)
                        .map(|(batch, publication_guard)| TablePayload::Read {
                            batch,
                            publication_guard,
                        })
                }
                Gate::List => store.committed_ids_guarded_at(witness).map(
                    |(commit_ids, publication_guard)| TablePayload::Listed {
                        commit_ids,
                        publication_guard,
                    },
                ),
                Gate::Review(review) => {
                    #[derive(serde::Deserialize)]
                    struct Retention {
                        retention_ms: u64,
                    }
                    let ttl = serde_json::from_str::<Retention>(&review.content)
                        .map_err(|_| ())?
                        .retention_ms;
                    store
                        .review_guarded_at(&review.staging_id, ttl, witness)
                        .and_then(|(current, publication_guard)| {
                            if current != review {
                                return Err(bow_shock_evidence::Error("review changed".into()));
                            }
                            Ok(TablePayload::Reviewed {
                                review,
                                publication_guard,
                            })
                        })
                }
                Gate::AgentStatus(_) => unreachable!("handled agent publication"),
            };
        out.bytes = self.state.table(
            out.id,
            result.unwrap_or(TablePayload::Error {
                code: "publication_unavailable",
            }),
        );
        if out.bytes.len() > MAX_FRAME_BYTES {
            return Err(());
        }
        Ok(out)
    }
    fn start_clock(&mut self, task: ClockTask) -> Result<(), ()> {
        self.clock.as_ref().ok_or(())?.0.try_send(()).map_err(|_| {
            eprintln!("controller clock command unavailable");
        })?;
        self.clock_task = Some(task);
        self.clock_age = Some(Age::new());
        Ok(())
    }
    fn send_writer(&mut self, out: Outbound, writer: &SyncSender<Vec<u8>>) -> Result<(), ()> {
        writer.try_send(out.bytes).map_err(|_| {
            eprintln!("controller writer command unavailable");
        })?;
        self.writer_age = Some(Age::new());
        Ok(())
    }
    fn advance(&mut self, writer: &SyncSender<Vec<u8>>, done: &Receiver<bool>) -> Result<(), ()> {
        self.agent.poll();
        match done.try_recv() {
            Ok(true) => self.writer_age = None,
            Ok(false) => {
                eprintln!("controller writer ack failed");
                return Err(());
            }
            Err(TryRecvError::Disconnected) => {
                eprintln!("controller writer ack disconnected");
                return Err(());
            }
            Err(TryRecvError::Empty) => {}
        }
        if self
            .writer_age
            .as_ref()
            .is_some_and(|a| a.expired(IO_TIMEOUT))
        {
            eprintln!("controller writer handoff timeout");
            return Err(());
        }
        if self
            .clock_age
            .as_ref()
            .is_some_and(|a| a.expired(Duration::from_secs(1)))
        {
            eprintln!("controller clock task timeout");
            return Err(());
        }
        if self.clock_task.is_some() {
            let result = match self.clock.as_ref().expect("clock task").1.try_recv() {
                Ok(r) => Some(r),
                Err(TryRecvError::Empty) => None,
                Err(TryRecvError::Disconnected) => return Err(()),
            };
            if let Some(result) = result {
                self.clock_age = None;
                let task = self.clock_task.take().expect("task");
                let witness = result.map_err(|error| {
                    let diagnostic: String = error.0.chars().take(256).collect();
                    eprintln!("native clock failed: {diagnostic}");
                })?;
                match task {
                    ClockTask::Open => {
                        if self.finished.is_some() {
                            return Ok(());
                        }
                        let c = self.config.as_ref().expect("table mode");
                        self.store = Some(
                            Store::open_with_clock_owner(
                                &c.db,
                                self.state.run_id.as_deref().expect("initialized"),
                                witness,
                                &c.probe,
                                self.clock_owner.clone(),
                            )
                            .map_err(|_| ())?,
                        );
                        self.open_needed = false;
                    }
                    ClockTask::Poll => {
                        // A managed review consumes this unique native witness.
                        // Never reuse it through a second *_at operation.
                        if !self.check_agent(witness.clone()) {
                            self.store
                                .as_mut()
                                .expect("poll store")
                                .poll_at(witness)
                                .map_err(|_| ())?;
                        }
                        self.store.as_mut().expect("poll store").poll();
                        self.last_poll = Instant::now();
                    }
                    ClockTask::Operation(pending) => {
                        if self.finished.is_none() {
                            self.execute(pending, witness)?;
                        }
                    }
                    ClockTask::Publication(out) => {
                        if self.finished.is_some() {
                            return Ok(());
                        }
                        if self.writer_age.is_some() {
                            if self.outgoing.len() >= QUEUE {
                                return Err(());
                            }
                            // Urgent control may have used the writer during the
                            // query. Keep its gate and resample after readiness.
                            self.outgoing.push_front(out);
                        } else {
                            let out = self.publish(out, witness)?;
                            self.send_writer(out, writer)?;
                        }
                    }
                }
            }
        }
        if let Some(store) = &mut self.store {
            store.poll();
            if store.health() == Health::Failed {
                eprintln!("controller store failed");
                return Err(());
            }
            if store.health() == Health::Closed
                && let Some(id) = self.closing.take()
            {
                self.table(id, TablePayload::Closed, None)?;
            }
        }
        // Control replies do not depend on a slow/failed native query.
        let ready_index = if self.clock_task.is_none() {
            (!self.outgoing.is_empty()).then_some(0)
        } else {
            self.outgoing.iter().position(|out| out.gate.is_none())
        };
        if self.writer_age.is_none()
            && let Some(index) = ready_index
        {
            let out = self.outgoing.remove(index).expect("checked outgoing");
            if out.gate.is_some() {
                self.start_clock(ClockTask::Publication(out))?;
            } else {
                self.send_writer(out, writer)?;
            }
        }
        if self.clock_task.is_none() && self.finished.is_none() {
            if self.open_needed {
                self.start_clock(ClockTask::Open)?;
            } else if self
                .store
                .as_ref()
                .is_some_and(|s| s.health() != Health::Closed)
                && self.last_poll.elapsed() >= POLL_INTERVAL
            {
                self.start_clock(ClockTask::Poll)?;
            } else if let Some(pending) = self.pending.pop_front() {
                self.start_clock(ClockTask::Operation(pending))?;
            }
        }
        Ok(())
    }
}
impl Actor {
    fn current_review(
        &mut self,
        review: &Review,
        witness: ClockWitness,
    ) -> Result<(Batch, bow_shock_evidence::PublicationGuard), ()> {
        #[derive(serde::Deserialize)]
        struct Content {
            batch: Batch,
            retention_ms: u64,
        }
        if review.content.len() > MAX_REVIEW {
            return Err(());
        }
        let content: Content = serde_json::from_str(&review.content).map_err(|_| ())?;
        let (current, guard) = self
            .store
            .as_mut()
            .ok_or(())?
            .unapproved_review_guarded_at(&review.staging_id, content.retention_ms, witness)
            .map_err(|_| ())?;
        if current != *review {
            return Err(());
        }
        Ok((content.batch, guard))
    }
    fn start_agent(
        &mut self,
        id: u64,
        review: Review,
        ids: Vec<String>,
        objective: String,
        ttl: u64,
        witness: ClockWitness,
    ) -> Result<(), ()> {
        let result = (|| {
            if objective.is_empty() || objective.len() > 2048 || ttl == 0 || ttl > 60000 {
                return Err(());
            }
            let (batch, mut guard) = self.current_review(&review, witness.clone())?;
            native_batch(&batch, &witness).map_err(|_| ())?;
            guard.valid_until_ns = guard.valid_until_ns.min(
                witness
                    .continuous_ns
                    .checked_add(ttl.checked_mul(1_000_000).ok_or(())?)
                    .ok_or(())?,
            );
            let fields = crate::agent::projection(&batch, &ids)?;
            let task_id = format!("agent-{id}");
            self.agent.start(crate::agent::Task {
                id: task_id.clone(),
                review,
                guard: guard.clone(),
                fields,
                objective,
                generation: self.state.generation,
            })?;
            Ok(TablePayload::AgentStarted {
                task_id,
                publication_guard: guard,
                candidate_ids: ids,
            })
        })();
        self.table(
            id,
            result.unwrap_or(TablePayload::AgentError {
                code: "agent_rejected",
            }),
            None,
        )
    }
    fn check_agent(&mut self, witness: ClockWitness) -> bool {
        let Some(task) = self.agent.task.clone() else {
            return false;
        };
        if !matches!(
            self.agent.task_state,
            crate::agent::TaskState::Running
                | crate::agent::TaskState::Candidate
                | crate::agent::TaskState::NoMatch
        ) {
            return false;
        }
        let current = self.current_review(&task.review, witness.clone());
        if witness.boot_id != task.guard.boot_id
            || witness.continuous_ns >= task.guard.valid_until_ns
        {
            self.agent.retire(crate::agent::TaskState::Expired);
        } else if task.generation != self.state.generation || current.is_err() {
            self.agent.retire(crate::agent::TaskState::Canceled);
        }
        true
    }
}
fn native_batch(batch: &Batch, witness: &ClockWitness) -> Result<(), bow_shock_evidence::Error> {
    if batch.rows.is_empty()
        || batch.rows.len() > 2
        || batch
            .rows
            .iter()
            .any(|r| r.fields.is_empty() || r.fields.len() > 6)
        || serde_json::to_vec(batch)
            .map_err(|e| bow_shock_evidence::Error(e.to_string()))?
            .len()
            > MAX_BATCH
    {
        return Err(bow_shock_evidence::Error("native batch budget".into()));
    }
    for field in batch.rows.iter().flat_map(|r| &r.fields) {
        let o = &field.source.observation;
        if !matches!((o.capture_start_ns,o.capture_end_ns),(Some(a),Some(b)) if a>0 && a<=b && b<=witness.continuous_ns)
        {
            return Err(bow_shock_evidence::Error(
                "actual capture interval required".into(),
            ));
        }
        match &field.state {
            FieldState::Value { source, .. } | FieldState::Invalid { source, .. }
                if field.source.fragment.as_ref() != Some(source) =>
            {
                return Err(bow_shock_evidence::Error("raw fragment mismatch".into()));
            }
            FieldState::Empty if field.source.fragment.is_none() => {
                return Err(bow_shock_evidence::Error(
                    "observed empty requires actual fragment".into(),
                ));
            }
            FieldState::Missing | FieldState::Inaccessible if field.source.fragment.is_some() => {
                return Err(bow_shock_evidence::Error(
                    "absent field has no source fragment".into(),
                ));
            }
            FieldState::Ambiguous { candidates }
                if field.source.fragment.as_ref().is_some_and(|fragment| {
                    field.source.node_id.is_none()
                        || candidates
                            .iter()
                            .any(|candidate| candidate.is_empty() || !fragment.contains(candidate))
                }) =>
            {
                return Err(bow_shock_evidence::Error(
                    "ambiguous literals require their actual whole-cell fragment and node".into(),
                ));
            }
            _ => {}
        }
    }
    Ok(())
}
pub fn serve(config: Option<Config>) -> bool {
    let (incoming, writer, done) = io_workers();
    let mut actor = Actor::new(config);
    let result = 'service: loop {
        if actor.finished.is_none() {
            // Finite work per turn. Reader backpressure never blocks this owner.
            for _ in 0..QUEUE {
                match incoming.try_recv() {
                    Ok(event) => {
                        if actor.incoming(event).is_err() {
                            eprintln!("controller incoming branch failed");
                            break 'service failed(&mut actor);
                        }
                    }
                    Err(TryRecvError::Empty) => break,
                    Err(TryRecvError::Disconnected) => break,
                }
                if actor.finished.is_some() {
                    break;
                }
            }
        }
        if actor.advance(&writer, &done).is_err() {
            eprintln!("controller advance branch failed");
            break failed(&mut actor);
        }
        if let Some(success) = actor.finished
            && actor.outgoing.is_empty()
            && actor.writer_age.is_none()
            && actor.clock_task.is_none()
        {
            break success;
        }
        thread::sleep(Duration::from_millis(1));
    };
    // Terminal phase only: no authority admissions and no blocking pipe joins.
    actor.clock_owner.cancel();
    actor.agent.shutdown();
    let mut warning = Some(Age::new());
    while !actor.clock_owner.is_quiescent() || !actor.agent.quiescent() {
        if warning
            .as_ref()
            .is_some_and(|age| age.expired(Duration::from_secs(2)))
        {
            eprintln!("clock reap not reconciled; remaining terminal until owned queries quiesce");
            warning = None;
        }
        thread::sleep(Duration::from_millis(1));
    }
    result
}
fn failed(actor: &mut Actor) -> bool {
    actor.agent.shutdown();
    actor.clock_owner.cancel();
    if let Some(store) = &mut actor.store {
        store.stop();
    }
    // Cancel probes before terminal quiescence; never join stalled pipe threads.
    eprintln!("controller terminal failure; table disposition remains dirty/unknown");
    false
}
