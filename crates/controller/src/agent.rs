//! Host-owned selection proposals. No staging, approval or database write here.
use bow_shock_evidence::{Batch, Field, PublicationGuard, Review, Row};
use serde::{Deserialize, Serialize};
use std::{
    collections::BTreeSet,
    path::PathBuf,
    sync::{
        Arc, Mutex,
        atomic::{AtomicBool, Ordering},
        mpsc::{self, Receiver, SyncSender},
    },
    thread,
};

#[derive(Clone)]
pub struct Settings {
    pub executable: PathBuf,
    pub cwd: PathBuf,
    pub home: PathBuf,
    pub user_home: PathBuf,
    pub model: String,
    pub provider: String,
    pub account: Option<String>,
}
#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct Descriptor {
    pub runtime: &'static str,
    pub version: &'static str,
    pub role: &'static str,
    pub placement: &'static str,
    pub model: String,
    pub provider: String,
    pub account_ref: String,
    pub account_type: String,
    pub protocol_version: u32,
    pub account_verification: &'static str,
    pub structured_output: &'static str,
    pub history: &'static str,
    pub steer: &'static str,
    pub cancellation: &'static str,
}
#[derive(Debug, Clone, Copy, Serialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum Disclosure {
    NotTransmitted,
    TransportHandoffStarted,
    PartiallyTransmitted,
    ProviderRetainedUnknown,
}
#[derive(Clone)]
pub struct Fence {
    pub live: bool,
    pub task_id: String,
    pub disclosure: Disclosure,
    pub expired: bool,
}
#[derive(Clone, Serialize)]
pub struct SelectedField {
    pub candidate_id: String,
    pub row: usize,
    pub field: Field,
}
#[derive(Clone)]
pub struct Task {
    pub id: String,
    pub review: Review,
    pub guard: PublicationGuard,
    pub fields: Vec<SelectedField>,
    pub objective: String,
    pub generation: u64,
}
#[derive(Debug, Clone, Serialize)]
pub struct Proposal {
    pub candidate_ids: Vec<String>,
    pub batch: Batch,
    pub explanation: String,
}
#[derive(Clone, Copy, Serialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum TaskState {
    Idle,
    Running,
    Candidate,
    NoMatch,
    Canceled,
    Expired,
    Failed,
}
#[derive(Serialize)]
pub struct Status {
    pub task_id: Option<String>,
    pub state: TaskState,
    pub export_disposition: Disclosure,
    pub publication_guard: Option<PublicationGuard>,
    pub proposal: Option<Proposal>,
    pub code: Option<&'static str>,
}
pub enum Work {
    Metadata,
    Propose(Box<(Task, Descriptor)>),
}
pub enum Completion {
    Metadata(Result<Descriptor, ()>),
    Final(String, Result<Option<Proposal>, ()>),
}
pub struct Manager {
    commands: Option<SyncSender<Work>>,
    completions: Receiver<Completion>,
    pub descriptor: Option<Descriptor>,
    pub metadata_state: &'static str,
    pub task: Option<Task>,
    pub task_state: TaskState,
    proposal: Option<Proposal>,
    pub fence: Arc<Mutex<Fence>>,
    stopping: Arc<AtomicBool>,
    active: Arc<AtomicBool>,
}
impl Manager {
    pub fn new(
        settings: Option<Settings>,
        probe: PathBuf,
        clock: bow_shock_evidence::ClockOwner,
    ) -> Self {
        let (done, completions) = mpsc::sync_channel(2);
        let fence = Arc::new(Mutex::new(Fence {
            live: false,
            task_id: String::new(),
            disclosure: Disclosure::NotTransmitted,
            expired: false,
        }));
        let stopping = Arc::new(AtomicBool::new(false));
        let active = Arc::new(AtomicBool::new(false));
        let commands = settings.map(|settings| {
            let (send, receive) = mpsc::sync_channel(1);
            let fence = fence.clone();
            let stopping = stopping.clone();
            let active = active.clone();
            active.store(true, Ordering::SeqCst);
            thread::spawn(move || {
                struct Finished(Arc<AtomicBool>);
                impl Drop for Finished {
                    fn drop(&mut self) {
                        self.0.store(false, Ordering::SeqCst);
                    }
                }
                let _finished = Finished(active);
                while !stopping.load(Ordering::SeqCst) {
                    let work = match receive.recv_timeout(std::time::Duration::from_millis(20)) {
                        Ok(work) => work,
                        Err(mpsc::RecvTimeoutError::Timeout) => continue,
                        Err(mpsc::RecvTimeoutError::Disconnected) => break,
                    };
                    let completion = match work {
                        Work::Metadata => Completion::Metadata(super::agent_transport::metadata(
                            &settings, &stopping,
                        )),
                        Work::Propose(payload) => {
                            let (task, descriptor) = *payload;
                            let id = task.id.clone();
                            let result = super::agent_transport::propose(
                                &settings,
                                &probe,
                                &clock,
                                &stopping,
                                &fence,
                                &task,
                                &descriptor,
                            );
                            Completion::Final(id, result)
                        }
                    };
                    if done.try_send(completion).is_err() {
                        break;
                    }
                }
            });
            send.try_send(Work::Metadata).expect("empty metadata queue");
            send
        });
        Self {
            metadata_state: if commands.is_some() {
                "opening"
            } else {
                "unavailable"
            },
            commands,
            completions,
            descriptor: None,
            task: None,
            task_state: TaskState::Idle,
            proposal: None,
            fence,
            stopping,
            active,
        }
    }
    pub fn poll(&mut self) {
        while let Ok(completion) = self.completions.try_recv() {
            match completion {
                Completion::Metadata(result) => {
                    self.descriptor = result.ok();
                    self.metadata_state = if self.descriptor.is_some() {
                        "ready"
                    } else {
                        "unavailable"
                    };
                }
                Completion::Final(id, result)
                    if self.task.as_ref().is_some_and(|task| task.id == id)
                        && self.task_state == TaskState::Running =>
                {
                    if !self.fence.lock().expect("revocation lock").live {
                        continue;
                    }
                    match result {
                        Ok(Some(proposal)) => {
                            self.proposal = Some(proposal);
                            self.task_state = TaskState::Candidate;
                        }
                        Ok(None) => self.task_state = TaskState::NoMatch,
                        Err(()) => {
                            let expired = self.fence.lock().expect("revocation lock").expired;
                            self.retire(if expired {
                                TaskState::Expired
                            } else {
                                TaskState::Failed
                            });
                        }
                    }
                }
                _ => {}
            }
        }
    }
    pub fn start(&mut self, task: Task) -> Result<(), ()> {
        if self.task_state == TaskState::Running {
            return Err(());
        }
        let descriptor = self.descriptor.clone().ok_or(())?;
        self.retire(TaskState::Canceled);
        {
            let mut fence = self.fence.lock().expect("revocation lock");
            *fence = Fence {
                live: true,
                task_id: task.id.clone(),
                disclosure: Disclosure::NotTransmitted,
                expired: false,
            };
        }
        if self
            .commands
            .as_ref()
            .ok_or(())?
            .try_send(Work::Propose(Box::new((task.clone(), descriptor))))
            .is_err()
        {
            self.fence.lock().expect("revocation lock").live = false;
            return Err(());
        }
        self.task = Some(task);
        self.task_state = TaskState::Running;
        self.proposal = None;
        Ok(())
    }
    pub fn retire(&mut self, state: TaskState) {
        self.fence.lock().expect("revocation lock").live = false;
        if self.task.is_some() {
            self.task_state = state;
        }
        self.proposal = None;
    }
    pub fn status(&self) -> Status {
        let data = matches!(self.task_state, TaskState::Candidate | TaskState::NoMatch);
        Status {
            task_id: self.task.as_ref().map(|t| t.id.clone()),
            state: self.task_state,
            export_disposition: self.fence.lock().expect("revocation lock").disclosure,
            publication_guard: if data {
                self.task.as_ref().map(|t| t.guard.clone())
            } else {
                None
            },
            proposal: self.proposal.clone(),
            code: if self.task_state == TaskState::Failed {
                Some("provider_unavailable")
            } else {
                None
            },
        }
    }
    pub fn shutdown(&mut self) {
        self.retire(TaskState::Canceled);
        self.stopping.store(true, Ordering::SeqCst);
    }
    pub fn quiescent(&self) -> bool {
        !self.active.load(Ordering::SeqCst)
    }
}

pub fn projection(batch: &Batch, ids: &[String]) -> Result<Vec<SelectedField>, ()> {
    if ids.is_empty() || ids.len() > 12 || ids.iter().collect::<BTreeSet<_>>().len() != ids.len() {
        return Err(());
    }
    let mut selected = Vec::new();
    for (row, item) in batch.rows.iter().enumerate() {
        for (field_index, field) in item.fields.iter().enumerate() {
            let id = format!("r{row}f{field_index}");
            if ids.contains(&id) {
                selected.push(SelectedField {
                    candidate_id: id,
                    row,
                    field: field.clone(),
                });
            }
        }
    }
    if selected.len() != ids.len() {
        return Err(());
    }
    Ok(selected)
}
#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct Final {
    request_id: String,
    candidate_ids: Vec<String>,
    no_match: bool,
    explanation: String,
}
pub fn final_candidate(bytes: &[u8], task: &Task) -> Result<Option<Proposal>, ()> {
    if bytes.len() > 4096 {
        return Err(());
    }
    let value = super::agent_transport::strict_json(bytes)?;
    if !value.is_object() {
        return Err(());
    }
    let final_: Final = serde_json::from_slice(bytes).map_err(|_| ())?;
    if final_.request_id != task.id
        || final_.explanation.len() > 2048
        || final_.candidate_ids.len() > 12
        || final_.candidate_ids.iter().collect::<BTreeSet<_>>().len() != final_.candidate_ids.len()
        || final_
            .candidate_ids
            .iter()
            .any(|id| !task.fields.iter().any(|field| field.candidate_id == *id))
    {
        return Err(());
    }
    if final_.no_match {
        return if final_.candidate_ids.is_empty() {
            Ok(None)
        } else {
            Err(())
        };
    }
    if final_.candidate_ids.is_empty() {
        return Err(());
    }
    #[derive(Deserialize)]
    struct Content {
        batch: Batch,
    }
    let mut batch = serde_json::from_str::<Content>(&task.review.content)
        .map_err(|_| ())?
        .batch;
    batch.rows = (0..batch.rows.len())
        .filter_map(|row| {
            let fields: Vec<_> = task
                .fields
                .iter()
                .filter(|field| {
                    field.row == row && final_.candidate_ids.contains(&field.candidate_id)
                })
                .map(|field| field.field.clone())
                .collect();
            (!fields.is_empty()).then_some(Row { fields })
        })
        .collect();
    batch.partial = true;
    Ok(Some(Proposal {
        candidate_ids: final_.candidate_ids,
        batch,
        explanation: final_.explanation,
    }))
}
