# Empirical human input and actual page triggers

The operator requires the agent's behavior to be rooted in real human typing,
mistaken-key likelihoods, correction behavior, pointer movement and the full
key press/down/up and other trigger surface. Existing design language excluded
deliberate typos; replaced that blanket exclusion with measured error/correction
sequences. Kept current extraction/preview/recipe delivery order.

Read the earlier movement research, native-input design and runtime plan. Browsed
primary Aalto typing data/publication/capture source, Balabit original data,
MacKenzie/Soukoreff error-analysis papers, and W3C UI/Input/Pointer Events.
Acquired nine original artifacts, including the entire 1,572,785,433-byte typing
ZIP, full pinned mouse archive, capture source, three papers and three standards
snapshots. Aalto capture pin is 98dcee94dc6c0464b35e8ca43d60e1b225cc621f;
Balabit is d00d6f779254a2a917deeab4a5b7a9e8643bd91e. Original archives are intact;
clean extracted source/data subsets are declared in the restoration manifest.
No reference implementation was executed and no library was adopted.

Owned acquisition utility preserves originals and partial transfers, records
binary-plist acquisition history and checks retained hashes. Owned inspection
utility reads archives without expanding the full typing dataset. It inspected
the first 100 numeric participant files: 73,285 rows, six invalid rows/timings,
59,503 consecutive printable pairs with 9,431 rollover pairs. All 65 Balabit
training sessions contain 2,253,816 rows and 345,099 equal adjacent client
timestamps. These are data descriptions, not a fitted profile or mistake matrix.

The Aalto source associates down/press/up and suppresses alphabetic repeats;
its exported data cannot establish every browser-event detail. Error alignment
can be ambiguous and final text misses corrected mistakes. Mouse data uses RDP
and lacks current native device/target calibration. Recorded those boundaries,
data terms, exact hashes and restoration commands in the tracked source notes.

The new plan separates intent, native generation, browser receipt and actual
page/network effects. It includes conditional errors, joint timing/overlap,
composition, legacy keypress when emitted, pointer/mouse capture/coalescing,
wheel versus actual scroll and corrections' intermediate triggers. Keep dated
profile identity with attempts and preserve the data. Native executor/event
observation are still unimplemented; no input or OS permission change occurred.

Validation: actual acquisition and archive inspection completed successfully;
both owned utilities compile; scoped diff checks passed. Native product code
did not change, so no bundle rebuild or repeated browser/model run was needed.
Preserved unrelated clock work and the independent Blackbird checkout.
