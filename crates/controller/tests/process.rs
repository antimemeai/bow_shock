use std::io::Write;
use std::process::{Command, Stdio};
use std::thread;
use std::time::{Duration, Instant};

fn execute(input: &[u8]) -> (bool, Vec<serde_json::Value>, Vec<u8>) {
    let mut child = Command::new(env!("CARGO_BIN_EXE_bow-shock-controller"))
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .unwrap();
    let mut stdin = child.stdin.take().unwrap();
    let input = input.to_vec();
    let writer = thread::spawn(move || {
        let _ = stdin.write_all(&input);
    });
    let deadline = Instant::now() + Duration::from_secs(5);
    loop {
        if child.try_wait().unwrap().is_some() {
            break;
        }
        if Instant::now() > deadline {
            child.kill().unwrap();
            panic!("controller did not close within 5 seconds");
        }
        thread::sleep(Duration::from_millis(5));
    }
    writer.join().unwrap();
    let output = child.wait_with_output().unwrap();
    assert!(output.stdout.len() <= 4096, "unbounded bootstrap output");
    assert!(output.stderr.len() <= 1024, "unbounded diagnostics");
    let mut replies = Vec::new();
    if !output.stdout.is_empty() {
        assert_eq!(output.stdout.last(), Some(&b'\n'));
        for frame in output.stdout[..output.stdout.len() - 1].split(|b| *b == b'\n') {
            replies.push(serde_json::from_slice(frame).expect("stdout must be closed JSONL"));
        }
    }
    (output.status.success(), replies, output.stderr)
}

fn reply(op: &str, id: Option<u64>, generation: u64) -> serde_json::Value {
    let mut value = serde_json::json!({"version":1,"op":op,"run_id":"run-1", "stop_generation":generation,"active_powers":[]});
    if let Some(id) = id {
        value["id"] = id.into();
    }
    value
}

const INIT: &str = "{\"version\":1,\"op\":\"initialize\",\"run_id\":\"run-1\"}\n";

#[test]
fn positional_initialization_array_is_rejected() {
    rejects(b"[\"initialize\",1,\"run-1\"]\n", "invalid_message", vec![]);
}

fn rejects_initialized_array(op: &str) {
    rejects(
        format!("{INIT}[\"{op}\",1,1]\n").as_bytes(),
        "invalid_message",
        vec![reply("initialized", None, 0)],
    );
}

#[test]
fn positional_ping_array_is_rejected() {
    rejects_initialized_array("ping");
}

#[test]
fn positional_stop_array_is_rejected() {
    rejects_initialized_array("stop_all");
}

#[test]
fn positional_shutdown_array_is_rejected() {
    rejects_initialized_array("shutdown");
}

#[test]
fn initialization_ping_stop_and_shutdown_have_exact_state() {
    let input = format!(
        "{INIT}{{\"version\":1,\"op\":\"ping\",\"id\":1}}\n{{\"version\":1,\"op\":\"stop_all\",\"id\":4}}\n{{\"version\":1,\"op\":\"stop_all\",\"id\":5}}\n{{\"version\":1,\"op\":\"shutdown\",\"id\":6}}\nmalformed-after-shutdown\n"
    );
    let (success, replies, stderr) = execute(input.as_bytes());
    assert!(success);
    assert!(stderr.is_empty());
    assert_eq!(
        replies,
        vec![
            reply("initialized", None, 0),
            reply("pong", Some(1), 0),
            reply("stopped", Some(4), 1),
            reply("stopped", Some(5), 2),
            reply("shutdown", Some(6), 2)
        ]
    );
}

#[test]
fn clean_eof_closes_without_invented_reply() {
    let (success, replies, stderr) = execute(b"");
    assert!(success);
    assert!(replies.is_empty());
    assert!(stderr.is_empty());
    let (success, replies, _) = execute(INIT.as_bytes());
    assert!(success);
    assert_eq!(replies, vec![reply("initialized", None, 0)]);
}

fn rejects(input: &[u8], code: &str, prefix: Vec<serde_json::Value>) {
    let (success, replies, _) = execute(input);
    assert!(!success, "invalid input must close unsuccessfully");
    let mut expected = prefix;
    expected.push(serde_json::json!({"version":1,"op":"error","code":code}));
    assert_eq!(replies, expected);
}

#[test]
fn closed_json_schema_rejects_malformed_and_surprising_input() {
    for bad in [
        "not-json",
        "[]",
        "null",
        "{}",
        "{\"version\":1,\"op\":\"evaluate\",\"script\":\"bad\"}",
        "{\"version\":1,\"op\":\"initialize\",\"run_id\":\"run-1\",\"extra\":true}",
        "{\"version\":1,\"op\":\"initialize\",\"run_id\":\"run-1\",\"run_id\":\"run-2\"}",
        "{\"version\":1,\"version\":1,\"op\":\"initialize\",\"run_id\":\"run-1\"}",
        "{\"version\":1,\"op\":\"initialize\",\"op\":\"initialize\",\"run_id\":\"run-1\"}",
        "{\"version\":\"1\",\"op\":\"initialize\",\"run_id\":\"run-1\"}",
        "{\"version\":1,\"op\":\"initialize\",\"run_id\":null}",
        "{\"version\":1,\"op\":\"ping\",\"id\":-1}",
        "{\"version\":1,\"op\":\"ping\",\"id\":1.0}",
        "{\"version\":1,\"op\":\"ping\",\"id\":18446744073709551616}",
        "{\"version\":1,\"op\":\"initialize\",\"run_id\":\"run-1\"} {}",
    ] {
        rejects(
            format!("{bad}\n{INIT}").as_bytes(),
            "invalid_message",
            vec![],
        );
    }
}

#[test]
fn ordering_version_and_identity_are_checked() {
    rejects(
        b"{\"version\":2,\"op\":\"initialize\",\"run_id\":\"run-1\"}\n",
        "unsupported_version",
        vec![],
    );
    for op in ["ping", "stop_all", "shutdown"] {
        rejects(
            format!("{{\"version\":1,\"op\":\"{op}\",\"id\":1}}\n").as_bytes(),
            "not_initialized",
            vec![],
        );
    }
    rejects(
        format!("{INIT}{INIT}").as_bytes(),
        "already_initialized",
        vec![reply("initialized", None, 0)],
    );
    for run_id in [
        "".to_string(),
        "x".repeat(129),
        "space name".into(),
        "é".into(),
        "line\nname".into(),
    ] {
        let input = format!(
            "{}\n",
            serde_json::json!({"version":1,"op":"initialize","run_id":run_id})
        );
        rejects(input.as_bytes(), "invalid_run_id", vec![]);
    }
    rejects(
        format!("{INIT}{{\"version\":1,\"op\":\"ping\",\"id\":0}}\n").as_bytes(),
        "invalid_request_id",
        vec![reply("initialized", None, 0)],
    );
    for id in [1, 2] {
        rejects(format!("{INIT}{{\"version\":1,\"op\":\"stop_all\",\"id\":2}}\n{{\"version\":1,\"op\":\"stop_all\",\"id\":{id}}}\n").as_bytes(), "stale_request_id",vec![reply("initialized",None,0),reply("stopped",Some(2),1)]);
    }
}

#[test]
fn maximum_ids_and_run_identity_preserve_the_parent_value() {
    let run_id = "x".repeat(128);
    let input = format!(
        "{}\n{{\"version\":1,\"op\":\"shutdown\",\"id\":18446744073709551615}}\n",
        serde_json::json!({"version":1,"op":"initialize","run_id":run_id})
    );
    let (success, replies, _) = execute(input.as_bytes());
    assert!(success);
    assert_eq!(
        replies,
        vec![
            serde_json::json!({"version":1,"op":"initialized","run_id":run_id,"stop_generation":0,"active_powers":[]}),
            serde_json::json!({"version":1,"op":"shutdown","id":u64::MAX,"run_id":run_id,"stop_generation":0,"active_powers":[]})
        ]
    );
}

#[test]
fn post_initialization_corruption_is_terminal() {
    for bad in [
        "{\"version\":1,\"op\":\"ping\",\"id\":1,\"extra\":true}",
        "{\"version\":1,\"op\":\"ping\",\"id\":1,\"id\":2}",
        "{\"version\":1,\"op\":\"ping\"}",
    ] {
        rejects(
            format!("{INIT}{bad}\n{{\"version\":1,\"op\":\"shutdown\",\"id\":2}}\n").as_bytes(),
            "invalid_message",
            vec![reply("initialized", None, 0)],
        );
    }
    rejects(
        format!("{INIT}{{\"version\":2,\"op\":\"stop_all\",\"id\":1}}\n").as_bytes(),
        "unsupported_version",
        vec![reply("initialized", None, 0)],
    );
    rejects(
        format!("{INIT}truncated").as_bytes(),
        "invalid_frame",
        vec![reply("initialized", None, 0)],
    );
}

#[test]
fn framing_faults_close_without_resynchronization() {
    for bad in [
        b"\n".to_vec(),
        b"bad\r\n".to_vec(),
        vec![0xff, b'\n'],
        b"{\"version\":1}".to_vec(),
        vec![b'x'; 65_537],
    ] {
        rejects(&bad, "invalid_frame", vec![]);
    }
    let mut input = vec![b'x'; 65_536];
    input.push(b'\n');
    rejects(&input, "invalid_message", vec![]);
}

#[test]
fn closed_stdout_terminates_instead_of_retrying_reply() {
    let mut child = Command::new(env!("CARGO_BIN_EXE_bow-shock-controller"))
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .unwrap();
    drop(child.stdout.take());
    child
        .stdin
        .take()
        .unwrap()
        .write_all(INIT.as_bytes())
        .unwrap();
    let deadline = Instant::now() + Duration::from_secs(5);
    while child.try_wait().unwrap().is_none() {
        if Instant::now() > deadline {
            child.kill().unwrap();
            panic!("failed output did not terminate");
        }
        thread::sleep(Duration::from_millis(5));
    }
    assert!(!child.wait_with_output().unwrap().status.success());
}
