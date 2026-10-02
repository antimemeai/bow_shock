//! Control-only child bootstrap. No grants or effect executors exist here.
//!
//! Synchronous IO is confined to this prototype process. When authority/effects
//! are added, bounded IO workers must keep pipe backpressure off their owner.

use bow_shock_controller_link::{FrameReader, FrameWriter};
use serde::de::{MapAccess, Visitor, value::MapAccessDeserializer};
use serde::{Deserialize, Serialize};
use std::fmt;
use std::io::{self, Read, Write};
use std::process::ExitCode;

const VERSION: u32 = 1;

#[derive(Deserialize)]
#[serde(tag = "op", rename_all = "snake_case", deny_unknown_fields)]
enum Request {
    Initialize { version: u32, run_id: String },
    Ping { version: u32, id: u64 },
    StopAll { version: u32, id: u64 },
    Shutdown { version: u32, id: u64 },
}

// Serde's tagged enum decoder also accepts positional sequences. The protocol
// requires objects, while forwarding the map preserves duplicate-key evidence.
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

impl Request {
    fn version(&self) -> u32 {
        match self {
            Self::Initialize { version, .. }
            | Self::Ping { version, .. }
            | Self::StopAll { version, .. }
            | Self::Shutdown { version, .. } => *version,
        }
    }
}

#[derive(Serialize)]
struct Reply<'a> {
    version: u32,
    op: &'static str,
    run_id: &'a str,
    #[serde(skip_serializing_if = "Option::is_none")]
    id: Option<u64>,
    stop_generation: u64,
    active_powers: [(); 0],
}

#[derive(Serialize)]
struct ErrorReply {
    version: u32,
    op: &'static str,
    code: &'static str,
}

struct Initialized {
    run_id: String,
    last_id: u64,
    stop_generation: u64,
}

#[derive(Default)]
struct State {
    initialized: Option<Initialized>,
}

impl State {
    fn apply(&mut self, request: Request) -> Result<Reply<'_>, &'static str> {
        if request.version() != VERSION {
            return Err("unsupported_version");
        }
        let (op, id) = match request {
            Request::Initialize { run_id, .. } => {
                if self.initialized.is_some() {
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
                self.initialized = Some(Initialized {
                    run_id,
                    last_id: 0,
                    stop_generation: 0,
                });
                ("initialized", None)
            }
            request => {
                let state = self.initialized.as_mut().ok_or("not_initialized")?;
                let (op, id) = match request {
                    Request::Ping { id, .. } => ("pong", id),
                    Request::StopAll { id, .. } => ("stopped", id),
                    Request::Shutdown { id, .. } => ("shutdown", id),
                    Request::Initialize { .. } => unreachable!(),
                };
                if id == 0 {
                    return Err("invalid_request_id");
                }
                if id <= state.last_id {
                    return Err("stale_request_id");
                }
                if op == "stopped" {
                    state.stop_generation = state
                        .stop_generation
                        .checked_add(1)
                        .ok_or("counter_exhausted")?;
                }
                state.last_id = id;
                (op, Some(id))
            }
        };
        let state = self.initialized.as_ref().ok_or("not_initialized")?;
        Ok(Reply {
            version: VERSION,
            op,
            run_id: &state.run_id,
            id,
            stop_generation: state.stop_generation,
            active_powers: [],
        })
    }
}

fn write<T: Serialize, W: Write>(writer: &mut FrameWriter<W>, value: &T) -> io::Result<()> {
    let payload = serde_json::to_vec(value).map_err(io::Error::other)?;
    writer.write_frame(&payload)
}

fn reject<W: Write>(writer: &mut FrameWriter<W>, code: &'static str) -> io::Result<bool> {
    write(
        writer,
        &ErrorReply {
            version: VERSION,
            op: "error",
            code,
        },
    )?;
    Ok(false)
}

fn serve<R: Read, W: Write>(input: R, output: W) -> io::Result<bool> {
    let mut reader = FrameReader::new(input);
    let mut writer = FrameWriter::new(output);
    let mut state = State::default();
    loop {
        let frame = match reader.read_frame() {
            Ok(Some(frame)) => frame,
            Ok(None) => return Ok(true),
            Err(_) => return reject(&mut writer, "invalid_frame"),
        };
        let request = match serde_json::from_slice::<ObjectRequest>(&frame) {
            Ok(ObjectRequest(request)) => request,
            Err(_) => return reject(&mut writer, "invalid_message"),
        };
        let reply = match state.apply(request) {
            Ok(reply) => reply,
            Err(code) => return reject(&mut writer, code),
        };
        write(&mut writer, &reply)?;
        if reply.op == "shutdown" {
            return Ok(true);
        }
    }
}

fn main() -> ExitCode {
    match serve(io::stdin().lock(), io::stdout().lock()) {
        Ok(true) => ExitCode::SUCCESS,
        Ok(false) => ExitCode::FAILURE,
        Err(_) => {
            eprintln!("controller output failed; connection closed");
            ExitCode::FAILURE
        }
    }
}
