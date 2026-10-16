# Recording native input and browser triggers

Use **Record input**, browse/type/scroll normally in that browser, then use
**Finish input**. **Stop** ends all active recordings along with the current
model/traffic operation. Typed values, intermediate mistakes and field state
are stored locally. Other apps and Oxcart conversation/editor windows are outside
the native scope. The browser's Chrome UI, including its address bar, is inside.

```sh
python3.13 scripts/try-poc.py https://www.python.org/ --record-input \
  --data-dir context/runtime/my-input-visit
```

Record across successive scroll/expanded states. **Read page** while recording
adds complete reading locators to the history. Navigation and reading markers
share IDs/locators with that browser's traffic session. The conversation prints
the input directory. A new recording creates a new UUID; late replies stay with
the old UUID.

Each `<data-dir>/input/<UUID>/` contains immutable `session.bplist` metadata
and ordered `events/<chunk>-<UUID>.bplist` files. Chunks flush at 128 records or
250 ms; these control storage, never sampling or total retention. All received
content is retained, including large values. Null uses `{oxcart_null: true}`.
Ill-formed UTF-16 uses `{oxcart_utf16le: <exact little-endian binary code units>}`;
valid text stays text. No automatic expiry or cleanup.

```sh
python3.13 scripts/input-inspect.py context/runtime/my-input-visit/input/UUID \
  --report context/runtime/my-input-visit/input-report.bplist
```

Inspection checks stored sequence continuity, counts actual native/browser event
types, reports paired native key holds/repeats and unmatched/focus-interrupted
keys, compares capture/deferred cancellation flags, and lists scroll-event
recipients. Reports refuse overwrite. These are observed episodes, not fitted
profiles or intended-key confusion matrices. All original events remain.

Native AppKit records precede application dispatch. They preserve key down/up,
modifiers, repeat, produced characters and available input-source identity;
pointer geometry/buttons/clicks/pressure/deltas; and wheel precision, direction,
phase and momentum. Window/display/focus context accompanies them. They cannot
recover coalesced-away hardware samples, identify the physical device, or prove
an event was human generated.

The fixed passive renderer observer starts after each ordinary frame context's
handshake. It records actual keyboard/legacy keypress, beforeinput/input/textInput/
composition, focus/selection, pointer/mouse/capture/click, wheel/scroll, form and
drag events. Coalesced pointer samples and input target ranges are saved where
available. A private closure callback carries native CEF values over renderer
IPC; the model receives no arbitrary JavaScript interface.

Each browser event has immediate `capture` state and, when obtainable, a later
`settled` sample. `sample_trigger` distinguishes a deferred task from cleanup.
Snapshot duration accompanies browser timestamps. Later state may include
intervening activity; neither sample establishes the complete reaction or cause.
Page-script events retain their actual `is_trusted`; that flag alone does not
prove human origin. Native uptime, DOM time/time origin and receipt time remain
separate clocks. Context-local node IDs are not DOMSnapshot node IDs. Use frame,
reading and traffic locators rather than silently merging unrelated nodes.

Coverage begins at `observer_started`. Page code can interfere, earlier handlers
can stop propagation, and workers/closed shadow internals are outside this
observer. Navigation/renderer termination may lose unsent events; a crash may
lose the unflushed native tail. Disk failure visibly stops acquisition. The
archive never retries an uncertain publication under a new name; published files
and failed partials remain. Pending data after a storage failure may be unavailable
on exit. Inspect stop/disabled/released/browser-close markers and errors.

The signed app builds and native event/archive plus observer lifecycle checks
pass. An unattended Python.org startup did not complete; a native stack sample
shows Chromium waiting in macOS Keychain `SecItemCopyMatching`/decrypt access.
Partial data and the sample remain under `context/runtime/input-live/`.
Human typing/IME/trackpad and actual Chromium
recipient comparisons remain for the practical session. There is no native
executor or calibrated shipping profile yet. Next fit coherent source episodes
with participant/session separation and explicit intent ambiguity, then introduce
bounded native actions against these observations.
