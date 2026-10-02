# Native construction observations

2026-10-02, macOS ARM64. Runtime: CEF
154.0.32+g682c378+chromium-154.0.8037.58, stable API15400; exact acquisition and
restoration are in [the runtime manifest](../../runtime/cef-macos-arm64.json).
This is the native construction milestone, not completion of P1 or the first
observation/table POC.

Build and run the owned fixture:

```sh
python3 scripts/cef-runtime.py acquire
python3 scripts/build-native.py
python3 tests/native_shell_smoke.py
python3 tests/controller_connection.py
```

The app, framework, five helper bundles and Rust controller are under ignored
`context/build/native/Bow Shock.app`. The build stages every controller/helper
after compilation, compares their actual bytes before signing, signs locally,
and requires `codesign --verify --deep --strict`. Signing changes Mach-O metadata,
so whole-file hashes after signing cannot decide whether staging copied the
current build. An actual second native relink passed the corrected packaging
path; the adopted macro needs a fresh staged framework to avoid nested symlinks.

The owned HTTP fixture loaded with its exact alpha title, HTTP200, and a visible
native Chrome-style window. Initialization, Stop generation1 and shutdown
succeeded; browser close preceded message-loop return, controller reap and
CefShutdown. The exact owned controller PID was absent after app exit. A real
Default/Preferences file and absence of the invalid-cache diagnostic establish
that the disposable dedicated profile persisted. All profile paths derive from
the same POSIX realpath; Foundation's `/private/var` alias handling failed this
direct check.

Eleven independent actual-class connection test methods cover live short
replies, exact Rust protocol compatibility, malformed replies, idle death,
closed parent stdio, nonblocking invalidation, continuous request expiry,
TERM-ignoring child cleanup, and final join. They do not exercise CEF helper
crashes, browser navigation history, or native reader workload. The CLI oracle
holds an NSProcessInfo activity to prevent App Nap coalescing its diagnostic
timers; that does not change the production connection.

## Process-role observations and remaining gates

The helper's test-only probe attempts opening two owned nonsecret files after
sandbox initialization and before loading CEF: one in Darwin per-user temporary
storage and one under project context outside the bundle/profile/temp/cache.
The former is a deliberate exception in some native policies. The latest run
also records service type and seatbelt-client presence:

| Role | Temp / project open | Bounded interpretation |
| --- | --- | --- |
| Renderer | EPERM / EPERM | These reads denied; seatbelt client present |
| GPU | Success / EPERM | Native GPU temp exception; seatbelt client present |
| NetworkService | EPERM / EPERM | Native network policy; seatbelt client present |
| StorageService and Unzipper | EPERM / EPERM | Native service policy; seatbelt client present |
| MacNotificationProvider | Success / success | Upstream explicit no-sandbox UI helper; no seatbelt client |

The smoke asserts role presence and expected scoped results, and every reported
helper PID disappears within five seconds of app exit. The build refuses an
observed live app/helper before replacing its bundle. The matched policy study
explains these results; they do not certify all filesystem/IPC privileges or
unobserved service roles.

No sandbox-off, certificate-bypass, site-isolation relaxation or public debugging
listener was introduced. These observations authorize continued owned-fixture
development, not untrusted-site capability certification.

One later run exited2 with Chromium's teardown watchdog after initial successful
runs. Its exact cause remains unresolved. Subsequent instrumented runs reached
both controller-join end and CefShutdown end; the latest canonical-profile smoke
passed. Do not label the earlier failure fixed without identifying its cause.
The smoke retains stderr and, for a slow owned process, a direct stack sample;
failed owned profiles remain in ignored runtime context for diagnosis.

The local ad-hoc build emitted Chromium's macOS process validation-category
diagnostic (-67030). An independent owned Security/Foundation probe identified
Info.plist serialization/signature mismatch. Canonicalizing only owned generated
app/helper plists before signing removed the diagnostic in the actual native
smoke; strict static verification also passes. Ad-hoc code still does not supply
authenticated signing identity. See [the matched policy study](../../papers/native-process-policies.md).

Still open from N1: navigation/back and renderer/helper-death outcomes; additional
service/privilege coverage; whole-bundle supported-version servicing on a
disposable profile; the unresolved teardown failure. N2/N2a/N3 reader identity,
independent control and native capture-work limits remain subsequent gates.
No model, OS input, network mutation, DOM projection or table storage is enabled
by this construction milestone.
