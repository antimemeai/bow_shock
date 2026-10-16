# Empirical native input and browser triggers

Operator direction, 2026-10-16: how the agent acts must be rooted in real human
typing, error and pointer data, including the probability of pressing a particular
wrong key given the intended one. Cover key press/down/up and every relevant
browser trigger. This applies to page-local exploration in extraction as well as
later delegated tasks. Existing native input is still unimplemented.

## Behavior profiles from real sequences

Keep intended content/action, generated input and observed outcome as separate
records. Derive dated behavior profiles from preserved original human traces;
record data version, cohort/device/layout/task, fitting procedure and remaining
unknowns. Each execution binds the exact profile used, independently of its
page-type extraction recipe. Preserve superseded profiles and their source data.

Typing needs joint down/up/hold and inter-key timing, including overlap/rollover,
modifiers, repeat, word boundaries, pauses and correction episodes. Model errors
as conditional behavior: intended key/context to observed key, insertion,
omission, transposition, recognition delay and correction strategy. Keep physical
key/code and produced character distinct across layouts and composition. Fit
conditional mistaken-key probabilities from actual observations; keyboard
adjacency is a possible feature, not a measured confusion matrix by itself.
Retain counts, cohort and uncertainty rather than inventing a probability for
an unseen pair. Preserve ambiguities in intended-key alignment.

Pointer behavior needs timestamped paths, movement duration/velocity, curvature,
overshoot/correction, hover and button down/up/dwell; keep drag and double-click
episodes distinct. Condition on target size/distance and device/display context
when available. Scrolling needs separate wheel/trackpad profiles, bursts, pauses,
direction changes, momentum and the actual nested scroll recipient. Do not
transfer remote-desktop sampling intervals into a native-device distribution
without accounting for the recording path.

Start with the acquired source studies and data in
[the human-input reading note](../../papers/empirical-human-input.md). They are
research inputs, not a calibrated shipping profile. Where browser/device context
is absent, record the gap and collect ordinary scoped Oxcart interaction traces
when implementing that surface. No fixed human speed, independent per-event
jitter or guessed universal typo frequency substitutes for these data.

## Let the browser process the input

The native executor generates OS input and lets Chromium run its real event
and default-action machinery. Setting a field's value or independently scripting
a list of DOM events does not establish the same interaction.

Observe keyboard down/up and legacy keypress when emitted, repeat/modifiers,
beforeinput/input/inputType, composition start/update/end, selection, focus/blur,
change and any resulting activation/submission. The familiar printable-key
sequence is conditional: cancellation, IME, held keys, focus changes and page
handlers change what occurs. Preserve the actual target and timing per event;
keydown and keyup need not reach the same element. A field's final correct value
does not erase intermediate typo-triggered suggestions, validation or requests.

For pointing, observe pointer/mouse boundary and move/down/up/click events,
capture/cancellation and coalescing where the runtime exposes them. For scroll,
observe wheel input, actual scroll changes and resulting loaded content; wheel
events alone do not establish that the intended region scrolled. Keep native
posted-event records distinct from browser delivery and site reaction. Native
delivery and read-only event observation require source study against the actual
CEF build; no unrestricted page-script execution is delegated to the model.

## Implementation and direct checks

Keep the extraction/preview/recipe delivery order. Before adding a native action,
implement its trace recording and an initial profile grounded in relevant data.
For a real live task, compare complete human and generated episodes under the
same recorded conditions, inspect the received sequence and resulting behavior,
and fix concrete mismatches. Preserve intermediate errors/corrections, timing,
page changes and correlated network events for later study. Native cancellation
and human takeover remain active through held keys/buttons and corrections.

Event semantics and empirical resemblance are separate questions. Check actual
recipient/state changes directly, and use held-out human episodes for behavioral
comparison. Do not turn this into advance certification of every website.
