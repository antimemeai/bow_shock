# Independent control/clock bundle packaging

Root wrote the packaging sub-plan and actual-bundle oracle. Red failed because
Contents/MacOS/bow-shock-native-control did not exist. CMake now builds that
Foundation-only original executable with the existing continuous-clock source,
and app packaging stages both it and the original native clock probe.

The canonical build script stages all eight owned controller/clock/control/CEF
helper binaries on every invocation, compares actual source/staged bytes before
signing, explicitly signs the three standalone executables and verifies them
plus the complete app. CMake's main target depends on both small native targets.
No new dependency, entitlement, keychain permission or input API is introduced.

The full script passed (context/runtime/native-control-packaging-build.log).
The actual bundled helper initialized, acknowledged Stop generation 1 and
shutdown with exact bytes/EOF/exit. Strict executable/app signatures passed;
the bundled clock returned the actual boot UUID confirmed by external sysctl.
No CEF browser was launched for these outcomes.

Independent review in papers/native-control-packaging-code-review.md repeated
the actual oracle and inspected dependencies, signatures, staging and build
targets; no blocking finding remained. Plain CMake postbuild alone is not the
canonical dependency-only fresh-staging/signature path. Use build-native.py.
The service owner's later small Stop/clock-stall correction requires a new
controller build before service/UI acceptance; this packaging result concerns
the independently reviewed native helper/clock only. Parent connection, CEF-load
independence and native capture qualification remain separate integration gates.
