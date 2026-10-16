# Native and browser input observation

2026-10-16. Read the acquired UI Events/Input Events/Pointer Events studies in
[empirical human input](empirical-human-input.md), and the actual adopted CEF
15400 headers: `cef_render_process_handler.h`, `cef_client.h`, `cef_frame.h`,
`cef_browser.h`, `cef_v8.h`, `cef_values.h`, `cef_process_message.h`.
The distribution remains pinned by `runtime/cef-macos-arm64.json` and restored
by the existing runtime acquisition utility. V8 values stay on their context's
thread; context references must be removed at OnContextReleased. Frame process
messages carry CefListValue/CefDictionaryValue directly. A callback passed into
a fixed observer closure avoids exporting a native function on window.

Read the macOS 26.2 SDK AppKit headers `NSEvent.h` and
`NSTextInputContext.h`. Accessors have event-type restrictions: characters and
repeat belong to key events; button/pressure/click counts to applicable mouse
events; precise deltas, phase, momentum and inversion to scroll events.
`currentInputContext.selectedKeyboardInputSource` gives the selected input
source when an input context exists, not a physical keyboard/device identifier.
No global event tap, Accessibility permission, event posting, or mouse-coalescing
setting is needed for application dispatch observation.

[Apple NSEvent documentation](https://developer.apple.com/documentation/appkit/nsevent)
distinguishes scrollingDeltaX/Y, precision and momentum.
[UI Events](https://www.w3.org/TR/uievents/) makes keyboard defaults conditional
on key, cancellation and composition. Observe what Chromium emits instead of
synthesizing an expected list. Capture-time defaultPrevented can precede later
cancellation; a deferred task can see the retained event's later flag but its
field/scroll sample may include intervening activity. Preserve both times.
Separate native event time, DOM event time, performance time origin and native
receipt time; asynchronous IPC does not prove one-to-one causation.

The recorder is scoped research instrumentation. It preserves typed content,
intermediate errors and page event state locally when explicitly enabled. It
does not fit a shipping behavior profile, promise invisible instrumentation, or
make a page's JavaScript trustworthy. Geometry/state reads and native IPC have
cost; keep that context with recorded episodes.
