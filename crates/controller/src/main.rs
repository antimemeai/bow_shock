//! Closed trusted-native controller child. No model/input/network/export powers.
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
