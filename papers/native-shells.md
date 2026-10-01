# Additional native shells and language bindings

Reviewed 2026-10-01. This is a narrow supplement to the
[engine comparison](browser-engines.md). Reading scope: acquired repository
READMEs and platform descriptions; it is not a binding correctness, packaging,
or security audit. The [ledger](acquisition.json) pins the studied revisions.

[cef-rs](https://github.com/tauri-apps/cef-rs) provides Rust bindings and CEF
examples. Its README lists x86-64 and ARM64 support on macOS and Linux and
describes a macOS application/helper bundler. It also explicitly says that the
build script can download CEF binaries when a shared installation is absent.
Study process ownership, callback lifetimes, and sandbox packaging before
choosing the binding. Acquisition here fetched source; no Cargo build was run.

[JCEF](https://github.com/chromiumembedded/java-cef) supplies another language
bridge to study. Its Java/JNI interfaces do not remove the underlying CEF
process, callback, and runtime-servicing responsibilities. No JVM or CEF runtime
was installed for this project.

[Wry](https://github.com/tauri-apps/wry) illustrates native webview integration
across platforms. Its README describes native macOS WebKit and Linux WebKitGTK,
with different Linux X11/Wayland integration paths. These are different engine
and platform commitments from owning CEF. The
[Tauri webview version reference](https://v2.tauri.app/reference/webview-versions/)
helps frame servicing of system-provided runtimes. Wry's README also flags
private macOS APIs for its devtools option; do not treat a cross-platform API
name as proof of equivalent public capabilities.

[qutebrowser](https://github.com/qutebrowser/qutebrowser) is a reference for
human keyboard commands, browser chrome, hints, and userscript integration.
The corpus makes it available for a deeper source pass. Its existence does not
establish a suitable permission boundary for model-driven actions.

These references broaden the implementation comparison. Language selection,
dependency adoption, distribution, update ownership, and native OS input remain
open decisions. See [catalog](shell-sources.json).
