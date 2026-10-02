# Package independent native control and clock

2026-10-02. The original control helper has its own continuous expiry and private
pipe oracle. Put that executable and the original clock probe beside the Rust
controller in the complete app bundle so the forthcoming native workflow can
select concrete owned paths. They introduce no permission request, OS input,
CEF dependency inside the control helper, keychain access or network effect.

Root owns CMake targets and packaging; helper source remains its owner's unit.
Compile the helper against Foundation and the same continuous-clock producer,
with strict warnings and the native C++ standard. App build depends on both
small executables; stage them on every packaging invocation, including when the
main app does not relink. Compare staged bytes with their actual build sources
before signing, then verify the complete app and each standalone executable.
Existing controller and CEF helper staging remain governed by their review.

Direct red: the actual app bundle lacks the owned control executable. Require
both files, strict signatures, a real initialized/fenced/shutdown pipe trace
from the bundled helper and an actual boot/continuous clock witness from the
bundled probe. No CEF app is launched for this packaging oracle. The helper
test driver solely signals/reaps its concrete unreaped child. Parent control
connection, busy-CEF independence and capture-work qualification follow; a
packaged executable alone does not satisfy those joins.
