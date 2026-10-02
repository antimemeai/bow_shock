# Read-only keychain prompt study

Root delegated a prompt diagnosis while awaiting exact operator dialog wording.
Read matched CEF682c378/Chromiuma6548414 browser initialization, async key
provider, generic-password query, settings and patch configuration; read Apple
keychain access/modified-app guidance and TN2206. Preserved selected exact-source
HTTP responses/hashes/restoration in the existing matched manifest. Reused the
existing teardown browser-process snapshot instead of retaining a duplicate.

[Report](../papers/native-keychain-prompts.md) distinguishes keychain unlock from
per-item authorization, fixed Chromium Safe Storage/Chromium names from profile
isolation, and current ad-hoc code-hash identity from durable certificate-based
identity. Read-only public framework byte inspection found Chromium Safe Storage
and no Chrome Safe Storage; no actual keychain was queried. Root independently
inspected the actual designated requirement and found cdhash-only signing.

Current adopted CEF has no item-name settings. Newer already-acquired CEF source
has a customization patch and fields behind CEF_NEXT; recorded as a possible
future adoption decision, not an available current API. Proposed smallest
durable path is stable app signing identity plus operator approval of only the
exact item if the wording confirms that diagnosis. Whole-keychain unlock is a
different issue. No application launch, credential/item read, signing/trust/ACL
change, or encryption bypass was performed. Startup/watchdog causes remain open.
