# Scoped input recording

Continued the operator's AFK implementation direction after traffic capture and
the successful retained-reading extraction. Chose real native/browser episode
recording as the next unit: acquired corpus timing alone lacks native macOS
trackpad, target and complete browser-trigger context. Read the pinned CEF V8,
renderer lifecycle, frame IPC and native value headers, macOS AppKit input
headers and existing human-event source notes before writing the unit plan in
`docs/plan/scoped-input-recording.md`. No new library or OS input posting.

Implemented explicit Record input/Finish input and launch `--record-input`.
AppKit dispatch snapshots remain distinct from actual renderer event observations.
A fixed passive observer closure and private V8 callback send CEF dictionaries,
lists and scalars directly over frame IPC. No internal JSON or model script.
Whole events persist in ordered immutable binary-plist chunks; navigation IDs,
reading locators and traffic session paths link the three streams. Contexts get
fresh UUIDs. Old archives remain open for their late replies after stop/restart;
all storage drains when the browser closes.

Native archive/event checks preserve all 515 ordered records, a >1Mi-character
Unicode payload, exact unpaired UTF-16 code units, a reply after stop/restart,
and explicit storage failure. Actual constructed NSEvents cover down/up, flags,
mouse buttons/coordinates/click count and a CG-created wheel event; no event is
posted. The observer lifecycle check uses Node's native EventTarget, checks a
later listener's cancellation and changed scroll sample, flush-on-cleanup and
fresh restart IDs. It does not claim to test Chromium dispatch or a website.
The inspector consumes those actual saved artifacts and recovers the expected
70 ms key hold, later cancellation and complete large-payload archive. Final
check artifacts: `context/build/input-checks/6c85801a-0f98-43fd-bb11-e58d9273bb9b`.

Reviewed frame/context lifetime, event accessor restrictions, stop/restart,
storage publication, data encoding and observer interference. Fixed findings:
drag events now preserve their actual button; invalid UTF-16 gets an exact
binary tag rather than a lossy string; capture versus cleanup/deferred samples
carry their sampling trigger; old-archive errors cannot stop a new recording;
an uncertain file publication is never retried under a new name and thereby
duplicated. Storage failure ends acquisition visibly. No hidden truncation,
native event posting, physical-device guessing, or fitted profile was added.

Tried a real Python.org visit with recording enabled. It retained the recording
start but did not reach renderer context observation within 45 seconds. Retained
that partial run at `context/runtime/input-live/98ba58ed-c884-411a-8247-7f0f4d17073e`.
A second diagnostic run sampled the native process after eight seconds; every
sample of one Chromium worker was inside Security's SecItemCopyMatching,
SecKeychainItemCopyContent and synchronous decrypt. Main thread was in the
ordinary AppKit run loop. Retained sample, logs and partial data at
`context/runtime/input-live/50d133b9-2b54-4439-ab41-4d257b286178`, then terminated
only that diagnostic browser after its wait. No security dialog was automated,
credential/encryption setting changed, or test browser left running. Actual
renderer/human typing/IME/trackpad comparisons await the operator's practical
session; this outcome is not reported as a successful live recorder check.

Built the default native bundle with the matched sandboxed CEF distribution;
all helpers and native code compile, relink, and pass the build utility's strict
deep signature verification. Log: `context/build/input-native-build.log`.
Python utility compilation and actual binary report export also pass. Updated
README's stale launcher order and network-workbench status while adding the
recorder instructions. Unrelated native-clock changes and the independently
active Blackbird checkout/index remain untouched.
