# Native agent startup configuration review

2026-10-02. Independently reviewed root's narrow `BSAgentConfiguration` and
`BSTableConnection` startup changes, the written native-agent control/tandem plan,
and the actual Foundation-parent/compiled-peer oracle. This review does not own
implementation and does not review the unfinished Rust proposal/export unit as
complete. No CEF, keychain, Codex inference or reference implementation launched.

**Disposition: accepted for trusted native startup selection. No blocking finding.**

The configuration retains copied executable/workspace/user-home/Codex-home URLs,
model and optional nonsecret account expectation behind readonly properties.
The original table constructor delegates with nil agent configuration. Start
requires file URLs and absolute bounded path strings, with bounded UTF-8 model/
account identities excluding NUL/CR/LF. A non-file executable URL fails before
the controller is spawned. Missing account expectation stays absent; no account
identity is invented from runtime metadata.

Launch builds explicit argv entries for the closed `--agent-*` startup options,
fixing provider to `openai`. Values are separate argument-array elements, not
shell command text or incoming page/proposal fields. NSString owners remain live
through the synchronous posix_spawn call. Controller inheritance remains exactly
`LANG=en_US.UTF-8`; user and Codex homes are trusted argv selection for the later
owned agent child, not inherited credentials/environment or copied account files.
The original pipes/CLOEXEC/spawn supervision, protocol decoder, bounded ordinary/
urgent slots, deadlines and process teardown were not modified by this subunit.

Actual red was the absent configuration API. Root retained an intermediate weak
environment-oracle failure: Apple Python injected interpreter environment values,
so it could not measure original spawn inheritance precisely. Replacing it with
the compiled C++ peer is the appropriate direct mechanism, not budget relaxation.
Root's final four tests passed in 7.752s in
`context/runtime/native-agent-configuration-final.log`. This reviewer independently
ran `python3 tests/table_agent_configuration.py`: all four passed in 9.439s.
That command builds the real ObjC++ parent and original clock code with strict
warnings, then an actual native peer, without CEF or a model turn.

The direct cases inspect selected startup option/value pairs and the actual
compiled child's environ; verify the old constructor has six original arguments
and no agent flags; verify optional account absence; and refuse an HTTPS agent
executable before creation of the peer's launch marker. The parent exercises
initialize/ping/shutdown and owned teardown. These are startup-configuration
oracles, not tests of the Rust agent child's HOME/CODEX_HOME construction, account
selection, effective thread settings, proposal decoding or export revocation.

Existence/canonical runtime-home match, actual installed version, account
reference, effective model/provider/workspace/policy, scoped byte handoff,
cancellation and owned agent cleanup remain the Rust owner's separate direct
oracles. The provider/account descriptor and native proposal UI join remain
later work. File-path selection and disabled tool flags do not establish
containment of an ordinary same-UID trusted coding peer. This narrow acceptance
does not promote general browser capture, browser tools or delegated effects.
