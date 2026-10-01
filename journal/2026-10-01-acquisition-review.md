# Focused acquisition utility review, 2026-10-01

Reviewed `scripts/acquire.py`, the live acquisition ledger, source catalogs and
selected extracted trees. Did not edit the running utility, catalogs, ledger or
references. Two small local synthetic archives in temporary directories directly
reproduced extraction defects; no upstream code was executed. Findings refer to
the initially reviewed 198-line utility and need disposition after fixes.

1. **High: cached artifacts can be relabeled with a changed origin or scope.**
   `extract` returns as soon as `quarantine/<id>` exists (lines 55–56), while
   `acquire` replaces the manifest's source URL/selected paths and marks success
   (lines 93–95, 109–118, 139–157). Expanding a synthetic extraction from `a.txt`
   to `a.txt,b.txt` left `b.txt` absent without error. Files-mode archives also
   omit selection from their cache key, so deleting only the tree still cannot
   acquire newly selected files. Documents similarly reuse `<id>.html/.pdf` even
   after their requested URL changes. Reject changed source identity or explicitly
   refresh it; rebuild extraction when scope changes, and regenerate files-mode
   archives for changed selections. Preserve the existing pin until an explicit
   repin rather than silently describing a different source.
2. **Medium: selected paths may be absent while status says acquired.** Tar
   extraction never records which requested paths matched. A missing-only
   synthetic selection returned an empty successful tree. The live `qtwebengine`
   record lists `README.md`, absent from its extracted tree. Check selected
   coverage before committing the tree and record missing paths as partial/failure
   with an explicit acquisition gap. Files-mode 404 errors should identify the
   requested path/URL, not just generic HTTP status; WebKit, Servo and Ladybird
   currently lack this failure detail.
3. **Medium: reuse replaces recorded byte identity instead of detecting change.**
   `identity` unconditionally replaces the previous digest (lines 139, 156).
   A modified cached archive/snapshot is thereby accepted as a new acquired
   identity; an existing extraction may still hold different bytes. Compare
   cached bytes with the prior recorded digest before reuse, fail on mismatch and
   preserve the original artifact. That uses the existing checksum directly,
   without adding another receipt system.
4. **Medium: submodule gaps are not represented in acquisition records.** GitHub
   archives omit gitlink payloads. Live empty/missing modules include DevTools MCP
   `third_party/devtools-frontend`, protocol `scripts/inspector_protocol`, Helena's
   library, Nyxt's 110 listed modules, and OSWorld's two modules. Source study need
   not acquire every dependency, but record these exclusions rather than imply
   a dependency-complete source tree. Where a module matters, catalog its URL and
   superproject-pinned gitlink revision separately.
5. **Medium: files-mode archives do not reproduce identical bytes.** `ZipFile.write`
   uses the freshly downloaded temporary file's current timestamp (line 133).
   Reconstructing the same pinned files gives a different archive checksum across
   runs. Use deterministic ZipInfo metadata when constructing the ZIP; selected
   raw-file snapshots cannot promise original executable modes unless those modes
   are fetched separately or the scope statement explicitly excludes them.
6. **Low: `--restore` has no behavior.** The argument is passed to `acquire` but
   never used; it can resolve refs/download missing artifacts just like ordinary
   acquisition. Either make restore consume existing pins/archives offline and
   clearly report absent prerequisites, or remove the flag and explain that
   ordinary acquisition rebuilds missing trees from available archives.

The base extraction uses Python's confined data filter, excludes Git directories
and common filesystem detritus, stages fresh trees and preserves source archives.
Those are useful mechanisms. Missing selected paths and submodules are corpus
scope/provenance issues, not grounds to run upstream projects or adopt dependencies.

## Follow-up after fixes

Re-read the revised utility and checked temporary fixtures with an isolated
`ROOT`; live catalogs, ledger and references were untouched. Verified selected
scope expansion in both archive and files modes; rejection of missing selected
paths while retaining the previous tree; TAR/ZIP traversal rejection; rejection
of changed cached bytes; restore retirement of the prior tree; and fixed ZIP
member timestamps producing identical reconstructed archive bytes. The revised
code also records submodule exclusions and identifies failed file requests.
These address the original six findings for the exercised paths.

One remaining **medium** retry defect was reproduced: acquire files selection
`a.txt`, expand to `a.txt,b.txt`, and simulate a transient download failure for
`b.txt`. The returned failed record has the new selection but the old ZIP
artifact. Retrying that failed record concludes scope did not change, reuses the
old ZIP, makes no fetch calls and fails again because `b.txt` is absent. Preserve
effective artifact/mode/selection metadata until success, storing requested scope
separately on failure, or explicitly compare artifact scope with requested scope.
Failed archive rebuilds can similarly lose the signal that a rebuild is needed.

Final focused retry check: after the additional metadata fix, an isolated files
fixture acquired `a.txt`, failed expansion to `a.txt,b.txt` on a transient fetch,
retained the effective prior selection and recorded the requested selection
separately. Retrying fetched `b.txt` and successfully installed the expanded
tree. No unresolved finding remains from these exercised cases; live catalogs,
ledger and reference trees were not mutated by the fixture.

A later isolated files-mode fixture exercised a selected path containing a space.
The utility percent-encodes the raw download URL while retaining the literal
path in its ZIP and extracted tree. The fixture passed without live writes.
