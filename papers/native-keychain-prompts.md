# Provisional macOS keychain prompt diagnosis

2026-10-02. Read-only study; the exact requesting app/item/dialog wording is
still pending. No keychain items or passwords were read, no ACL/signing/trust
settings changed, and no app launched for this study.

The matched Chromium154 key provider queries a generic-password item by fixed
service/account names. Unbranded defaults are **Chromium Safe Storage** /
**Chromium**; Chrome-branded defaults are Chrome Safe Storage / Chrome. The
actual acquired framework contains the former service string and not the
latter. Its browser process eagerly initializes the async key provider; the
matched feature is enabled by default. The worker obtains that random encryption
password from Keychain, creating it when absent, and derives the browser storage
encryption key. Denied access produces temporarily unavailable key material.
This is a browser encryption item, not a Codex/provider login.
([password source](https://chromium.googlesource.com/chromium/src/+/a654841425914cbb703a2931e07b70a83aedbafd/components/os_crypt/common/keychain_password_mac.mm),
[provider](https://chromium.googlesource.com/chromium/src/+/a654841425914cbb703a2931e07b70a83aedbafd/components/os_crypt/async/browser/keychain_key_provider.mm),
[browser initialization](https://chromium.googlesource.com/chromium/src/+/a654841425914cbb703a2931e07b70a83aedbafd/chrome/browser/browser_process_impl.cc),
[feature default](https://chromium.googlesource.com/chromium/src/+/a654841425914cbb703a2931e07b70a83aedbafd/chrome/common/chrome_features.cc))

Profile path, browser display name and bundle identifier do not namespace this
query. A fresh disposable profile still uses the same service/account and can
request access again. Its actual keychain location and item authorization have
not been inspected.

Distinguish two dialogs. A request to unlock the **login keychain** may mean it
is locked or its password differs from the user login password. A request by
**Bow Shock** to access **Chromium Safe Storage** is per-item authorization;
Allow Once intentionally prompts again on the next access. Apple also documents
that modified apps may require reauthorization.
([keychain lock](https://support.apple.com/guide/keychain-access/mac-keychain-password-kyca1242/mac),
[access choices](https://support.apple.com/guide/keychain-access/if-youre-asked-for-access-to-your-keychain-kyca1243/mac),
[modified app](https://support.apple.com/guide/keychain-access/if-a-trusted-app-asks-for-keychain-access-kyca1331/mac))

The current build signs ad-hoc on every invocation. Root's read-only codesign
inspection found a designated requirement expressed solely as a code hash.
Changing the executable changes that identity; keeping the same bundle ID or
path does not preserve its hash. Apple documents that default keychain access
tracks designated requirements. Repeated authorization after rebuilds is
therefore a supported mechanism, though not yet confirmed as this operator's
specific dialog cause. Canonicalizing the plist fixed a different signature
validation error; it does not supply a stable certificate identity.
([Apple TN2206](https://developer.apple.com/library/archive/technotes/tn2206/_index.html))

The smallest durable development route, if this is the Safe Storage item
dialog, is a stable certificate-backed signing identity and stable designated
requirement for Bow Shock, followed by operator authorization for this exact
app/item. An existing appropriate identity can be used; Apple notes that a
local self-signed identity can support keychain identity continuity without
requiring Developer ID distribution trust. This is a proposed signing decision,
not an action performed here. It neither guarantees every prompt disappears
nor warrants granting all applications access. If the dialog instead unlocks
the whole login keychain, address that lock/password condition separately;
certificate continuity cannot unlock it.

Native item-name isolation would also be desirable, but the adopted CEF
682c378/API15400 has no `keychain_service_name` or `keychain_account_name`
settings and no matched keychain customization patch. The separately acquired
newer CEF ff57d4e contains those fields behind **CEF_NEXT** and an
`os_crypt_keychain_config` patch. That is a research candidate for a deliberate
matched-runtime/API adoption review, not an available setting in our tuple.
Changing names creates/accesses a different encryption item and may make
existing encrypted profile data unreadable; plan migration or use a fresh
owned profile when adopting it. Do not disable encryption, use the mock-keychain
test switch, or broaden login-keychain ACLs to hide this prompt.
([current settings](https://github.com/chromiumembedded/cef/blob/682c378d70d5780061e96644dca16ddd8fd157a9/include/internal/cef_types.h),
[newer study settings](https://github.com/chromiumembedded/cef/blob/ff57d4eae16d36457895f2de115a71d502e85a08/include/internal/cef_types.h))

Selected matched source responses/digests/restoration are appended to
[the existing manifest](native-matched-source-manifest.json). The newer full
CEF archive is already preserved by [the general acquisition manifest](acquisition.json).
No causal claim is made about the earlier startup timeout or teardown watchdog.
