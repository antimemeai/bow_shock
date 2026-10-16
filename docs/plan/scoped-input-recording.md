# Scoped human input recording

2026-10-16. First implementation unit of empirical native input. Record ordinary
operator interaction before fitting a native action profile. Do not post input,
invent timing, or infer intended keys from the final field value.

Add an explicit Record input/Finish input control beside the live browser.
Recording belongs to that browser, persists across its navigations, and excludes
the Oxcart conversation/editor windows and other applications. Retain native
AppKit events before application dispatch, unchanged. Record key identity,
characters, modifiers, repeats and timestamps; pointer coordinates, buttons and
deltas; wheel precision, direction, phase and momentum. Save window/display and
current input-source context. These are delivered AppKit events, not unsampled
hardware measurements or proof of the DOM recipient.

The renderer installs one fixed, read-only event observer per ordinary frame
context on request. A private CEF V8 callback carries native dictionary/list/scalar
values over CefProcessMessage. No JSON and no model-supplied script. Capture
actual keydown/keypress/keyup, beforeinput/input/composition, selection/focus,
pointer/mouse/capture/click, wheel/scroll and form events. Preserve timestamps,
isTrusted, actual composed-path target identity, modifiers, input data/type,
field/selection state and available coalesced pointer samples. Record immediate
capture state separately from a later task's cancellation/field/scroll state.
Neither a late task nor a capture listener establishes the complete page reaction.
Closed shadow internals, workers, stopped propagation before our listener,
navigation before a deferred sample, and compromised page prototypes remain
observable coverage limits, not invented events.

Each recording has a UUID directory and immutable session metadata. Write every
event to native binary-plist chunks on an autoreleasing serial IO worker, with
no total count/byte/time cap. Chunk size/time control flushing, never sampling.
Persist stop, context, navigation, reading and traffic locators in the same
sequence. Route late renderer replies by recording UUID, including after Finish;
never assign them to the next recording. Flush renderer pending observations
when removing listeners. Retain the archive until browser close, then drain all
disk work before process shutdown. Disk failures must reach the panel; a crash
can lose the explicitly pending, unflushed tail. Do not claim atomic multi-file
durability or cross-clock timestamp equality.

Direct checks: actual native archive ordering and complete large payloads,
late-session routing, stop/restart, explicit IO failures, and observer behavior
against native EventTarget objects (event semantics, not a fake website).
Compile the renderer against the pinned CEF headers, build/sign the actual app,
and leave real human typing/IME/scroll comparisons for the operator's practical
session. Review lifecycle, event accessor validity, observer side effects and
retention once before landing.
