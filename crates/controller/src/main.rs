//! Closed trusted-native controller child; explicit grounded proposals, no input powers.
mod agent;
mod agent_transport;
mod protocol;
mod service;
use std::process::ExitCode;
fn main() -> ExitCode {
    match service::configuration() {
        Ok(config) => {
            if service::serve(config) {
                ExitCode::SUCCESS
            } else {
                ExitCode::FAILURE
            }
        }
        Err(()) => {
            eprintln!("invalid controller host configuration");
            ExitCode::FAILURE
        }
    }
}
