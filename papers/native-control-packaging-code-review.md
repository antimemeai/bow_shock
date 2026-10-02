# Native control helper packaging review

2026-10-02. Independent review of root's N2a packaging additions only:
`native/cef/CMakeLists.txt`, `scripts/build-native.py` and
`tests/native_control_packaging.py`. Read the closed helper subplan and the
owner's build evidence. Helper implementation was left untouched. No build,
CEF/browser launch, keychain probe or product edit was performed by this review.

No concrete blocking finding was identified for the documented build-script
entry point and current owned macOS ARM64 artifact. Parent helper IPC, fence
wiring and behavior while CEF is busy are not reviewed or claimed here.

## Targets and staged freshness

CMake compiles the original native/control/main.mm plus the existing original
continuous_clock.mm into bow-shock-native-control. The independent clock target
uses the original native_clock_probe.mm and same clock producer. Both targets
are dependencies of bow_shock, and POST_BUILD copies their actual TARGET_FILE
paths into Contents/MacOS. The helper links Foundation, not the CEF wrapper or
framework; it has ARC/exceptions and strict warning flags. Generated Ninja
commands confirm the intended source paths and Foundation-only explicit link.
No quarantine/reference sample implementation was adopted.

The documented canonical entry is scripts/build-native.py. It builds locked
Rust with the pinned toolchain, configures the pinned CEF tuple, and builds the
browser target with the native dependencies. After build commands complete it
unconditionally copies controller, native control and native clock binaries,
then refreshes the five existing owned CEF helper bundles. This runs even when
Ninja does not relink the browser. Plain CMake POST_BUILD alone is not claimed
to keep an already-linked bundle fresh after every dependency-only rebuild.
The existing observed-live-bundle guard precedes rebuilding/replacement.

Before signing, the script compares whole-file SHA-256 of every staged binary
against its compiled source artifact and aborts on mismatch. The owner's
retained context/runtime/native-control-packaging-build.log reports eight
matching staged binaries on the actual successful build. This reviewer did not
rebuild or recreate the owner's initial absent-helper red case. Signing changes
Mach-O signature metadata; post-sign whole-file hash differences are expected
and are not treated as stale-artifact evidence.

## Signing and privileges

The three standalone owned executables are signed explicitly, then the complete
app is signed and verified with deep/strict checks. Generated owned app/helper
plists are canonicalized before that signing, as required by the prior matched
signature investigation. Each standalone executable is separately verified
strict afterward. This review's actual bundle and two executable verification
passed via the existing packaging oracle.

Actual otool inspection of both new bundled executables shows only Foundation,
CoreFoundation, libc++, libSystem and libobjc dependencies; no CEF/framework or
AX/Security direct dependency was added. Code signatures are ad-hoc, flags0x2,
without a Team ID or emitted entitlement payload. Both are ordinary executable
files with mode0755. This establishes no newly packaged entitlement/input power;
it does not assert an OS sandbox, notarization, trusted distribution identity,
TCC permission or dynamic CEF process-validation result. The prior CEF/keychain
investigation is unaffected because no CEF process was launched.

## Direct bundled oracle

Independently ran `python3 tests/native_control_packaging.py` successfully in
1.129s. It executes the actual bundled control helper with owned private pipes,
minimal LANG environment and close_fds, then checks exact160-byte initialize,
Stop fence1 and shutdown replies, process exit0 and final stdout EOF. It owns
and reaps only that concrete child. It also executes the actual bundled clock
probe, checks its boot UUID against external sysctl and requires a positive
integer continuous timestamp. Static strict signature checks cover the two
executables and complete bundle.

The narrow trace proves the staged helper/clock are runnable with this wire
contract. It does not replace the helper's independent expiry/backpressure
suite, prove source identity of an edited unbuilt Rust service, or exercise a
live parent adapter. Root will rebuild the controller service after its separate
current review; those later bytes are outside this artifact observation.

Reviewed file SHA-256 values:

- CMakeLists.txt:988c5ccfac3c87645e68b5a4b34f1d824eff854ce915c97b7fff1f135bd3d7e5
- build-native.py:d340eb90c462980f27deb24018863d230006c01b0abe316cd69c0e081efa3895
- native_control_packaging.py:79da54226e88198bbc5c6f27bbffd985fcc4a28e35a4391bbf4f0afc0847b051

Native control source remains the reviewed
2c7fdacf895148365e8293ee5bdb15aa479699cc614dd78541a56b79221040e7.
