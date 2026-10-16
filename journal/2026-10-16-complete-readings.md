# Complete readings

The operator corrects capture ownership: harvest everything and save a structured
file plus adjacent blobs; Blackbird chooses ranges or whole-file consumption.
Read the actual native observer, CEF method-result contract and Blackbird's file
tool source. The current reader incorrectly limits harvested text/links/nodes,
callback size and time, and inlines a partial result into model context. Replace
that with the file-backed design in `docs/plan/complete-readings.md`. Use existing
Foundation binary-plist machinery; no new dependency or Blackbird source change.
All DOMSnapshot documents and original column values remain available locally;
human-readable text is an indexed view, not the sole retained source.

Implemented version1 binary-plist archives with the complete returned columnar
DOMSnapshot and indexed string table, large string blobs (64KiB storage-placement
threshold, no truncation), exact UTF-16LE blobs when UTF-8 cannot represent source
code units, all-document UTF-8 text views and columnar block byte indexes. Each
private staging directory publishes only after writes succeed; successful
readings are retained. A view-projection error is recorded while preserving the
complete source tables. Metadata retains both frame trees, computed-style names,
capture interval and coverage, including target/media/pixel limitations.

Removed text/fragment/link/node/string/document/attribute-work/callback-byte and
elapsed-time cutoffs. CEF's typed method-result callback routes by ID before
copying, replacing the generic event backlog. Projection and file writing remain
on the worker. UI/Blackbird receive a small artifact locator; no full page or
capped substitute is forced into model context. Blackbird source is unchanged;
its existing whole/ranged file tools and ordinary programs choose consumption.

Native direct checks pass: a source blob over25MiB,210000 nodes,1488 large text
fragments, multiple documents and exact Unicode/blob/indexed-text round trips.
The full source preserves previously filtered hidden/form-field strings. Disk-
full injection rejects partial publication and cleans staging; existing captures
survive a same-ID write attempt. Malformed view columns preserve the original
dataset with explicit views_complete=false. A failing Unicode test exposed an
NSError escaping an inner autorelease pool; retain the error strongly inside
the writer until publication/failure returns. Its direct disk-full regression
and exact UTF-16 source-code-unit case now pass. Avoid allocating a trimmed copy
of each large text fragment merely to test for whitespace.

The signed native app builds successfully and Python utility compilation/diff
checks pass. The first actual Wikipedia run hit the app's changed-hash Safe
Storage prompt, then the prior smoke-driver timer killed it before capture.
Removed the native smoke timer; the driver now has an optional explicit
--timeout for automation, and otherwise waits for completion/Stop. The owned
timed-out process was stopped before rebuilding. Current live request is
run-5akoyism, actual United States article plus a real Blackbird objective asking
it to read the saved files and report source URL, text-file byte length and last
nonempty line. macOS securityd identifies its pending item-access prompt for
PID67781; the operator was asked asynchronously to choose Allow. The run stays
open, without an invented reading deadline. No Keychain settings, encryption or
signing identity was changed to bypass this OS decision.
