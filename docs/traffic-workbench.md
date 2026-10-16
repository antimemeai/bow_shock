# Traffic workbench

The native **Traffic** button opens the selected browser's capture/editor window.
Capture starts when Oxcart attaches its DevTools observer; reload if the initial
navigation began before attachment. Each browser keeps its own observer while
switching windows. Opening the traffic window leaves editing disarmed.

Enter a URL glob, select Requests and/or Responses, and choose **Arm**. Only
matching stages pause. Select a pending exchange, edit its fields and headers,
optionally choose an arbitrary binary body file, then **Apply edits**. A zero-byte
file supplies an empty body. **Forward original** ignores editor changes.
Duplicate header lines are preserved. Request edits cover URL, method, headers
and body; response edits cover status, headers and body. Server side effects
already performed remain performed.

A selected response is consumed into 64 KiB stream chunks before it is ready to
forward/edit. This is a read size, with no total body limit. Forwarding thereafter
fulfills from the saved original bytes. Replacement bodies are saved separately.
Decoded response fulfillment removes stale Content-Encoding, Content-Length and
Transfer-Encoding headers. Redirect responses with Location and responses that
have no body remain header pauses; they are not read as streams.

**Stop / disarm**, and the conversation panel's **Stop**, forward ordinary pending
requests unchanged. A response whose body is currently being consumed is canceled
and its partial data retained. A completely collected response is forwarded from
its saved bytes. Fetch is disabled after pending decisions finish. Browser close
retains partials and waits for archive writes. Agent detachment retires old
callbacks, records gaps and disarms editing; **Resume capture** reattaches passive
capture. Failed commands leave their pause available for retry/cancel.
Closing the editor also stops/disarms its paused traffic; passive capture continues.

The lower selector inspects recent request/response events. Its 150-entry viewport
is only a UI window onto the archive: no event or body is expired or deleted.
**Reveal archive** opens the retained files. All other Network events, including
extra-info headers/cookies, failures, WebSocket messages and cache/worker metadata,
remain in the timeline. There is no ad/tracker classifier yet; their requests are
captured and editable through the same controls.

Each run writes `<data-dir>/traffic/<session UUID>/`:

- `session.bplist`: format, date and coverage.
- `events/<sequence>-<UUID>.bplist`: native ordered event/command records, wall
  time, host uptime and the observed navigation/reading context. Original events
  keep protocol IDs, redirect responses and attribution fields. External null is
  represented by the native tag `{oxcart_external_null: true}`.
- `blobs/<UUID>.bin`: binary chunks, reported request body bytes and replacement
  bodies. Text-only protocol returns are labeled as UTF-8 reconstruction.
- `bodies/<exchange UUID>.bplist`: passive stream chunks in body order, completion
  or failure, and fallback body/error. The initial buffered chunk precedes later
  data chunks even when callbacks arrive in another order.
- `pauses/<UUID>/original.bplist`: the request/header pause, rule revision and
  context. `upstream-body.bplist` describes its original response stream.
- `pauses/<UUID>/decisions/<UUID>.bplist`: immutable edit instructions, exact
  applied parameters and body references. Decision-result events distinguish
  command acceptance/rejection from subsequent observed traffic. A successful
  command alone does not establish that a recipient received the proposed bytes.

All files are binary plists or adjacent bytes, published without overwrite.
Storage errors stay visible; incomplete chunks and failed publications survive.
An original that cannot be saved is forwarded unchanged rather than edited.
Capture and disk writes run outside the browser UI callback; no model turn is
required to resolve traffic. Chunk metadata and UI summaries remain in memory;
whole passive response bodies do not. The browser protocol requires a complete
base64 argument for a selected fulfilled response, so that explicit operation
uses memory proportional to its body. The passive completed-body fallback also
has this protocol limitation if incremental capture is unavailable.
The matched Chromium fulfillment implementation also has a fatal check above
4,294,967,295 response bytes. Oxcart refuses that particular send before allocating
its argument; capture/retention have no corresponding limit. Choose a replacement
or cancel that consumed response. Serving larger edited responses requires a
different response-loader implementation.

Inspect and reconstruct without loading the whole archive into memory:

```
python3.13 scripts/traffic-inspect.py /path/to/traffic/SESSION
python3.13 scripts/traffic-inspect.py /path/to/traffic/SESSION --event events/FILE.bplist
python3.13 scripts/traffic-inspect.py /path/to/traffic/SESSION --body bodies/ID.bplist --output /tmp/body.bin
```

Exports refuse existing destinations and reject unavailable/incomplete bodies;
`--allow-partial` explicitly exports retained partial bytes. Keep their outcome
and representation with any later analysis.

Coverage is the current CEF DevTools target, not every independently attached
out-of-process frame/worker. This is a browser protocol workbench, not a wire-level
TLS proxy. Cached/service-worker responses may have no upstream exchange. Network
body retrieval may be absent/evicted, and multipart file bytes may be missing;
those are gaps, not empty bodies. Original Fetch response streams and subsequent
page-visible Network content stay distinct. Full proxy routing, replay, reusable
edit rules, extra target attachment and a native traffic comparison view remain
follow-on work against actual sites.

`python3.13 tests/traffic_session.py` checks actual native commands and files with
controlled protocol replies. The signed browser builds with these modules.
Live request/response editing and rendered effects still need practical testing;
the operator was AFK and the earlier browser was waiting at its Keychain dialog.
