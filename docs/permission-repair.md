# HuiDict permission repair

The October 1 update changed HuiDict's ad-hoc code signature. macOS still displayed an enabled
Screen Recording switch, but its TCC log rejected the updated executable against the previous
build's code hash. TCC is macOS's permission system. Re-enabling the same stale entry did not fix
the identity mismatch.

The repair makes three changes:

- Status checks use `CGPreflightScreenCaptureAccess` before calling ScreenCaptureKit. A missing
  effective grant never reaches the capture API during status polling.
- Repeated and concurrent capture lookups share one automatic permission request per process.
  Subsequent failures direct the reader to Settings; a later grant can still be detected.
- Local builds can use a persistent certificate in a dedicated keychain, created by
  `Tools/local-signing.py setup`. Different builds retain the same certificate-based designated
  requirement, the rule macOS uses to recognize compatible app updates. No system certificate
  trust or login-keychain search-list change is required.

The app and both services retain strict signature validation and exact code-hash XPC peer checks.
The persistent signer does not authorize arbitrary binaries sharing the bundle identifier.
Signing credentials are stored outside the repository and are not published.

## Verification

- Full Swift suite: 2,036 tests reported across seven targets, with optional licensed dictionary
  fixture tests skipped when unavailable.
- Tool suite: 58 tests plus 11 scheduler reference tests passed. The icon fixture comparison now
  ignores Finder's `.DS_Store` metadata while still comparing all generated artwork bytes.
- A two-version signing probe produced different executable hashes with the same designated
  requirement and verified the expected signing certificate.
- Build `2026.1001.94259` passed strict bundle, nested-service, and certificate verification.
- All nine Qwen translation checks passed through the newly signed app's authenticated helper
  service, using the existing local model without a download.
- Installed executable SHA-256:
  `57935b947348d1deccfdaed0d0b037f646626bf48eb2b14a08457aa5b37e58be`.

## Installed app verification

The October 1 permission refresh was completed for the installed app at
`~/Applications/HuiDict.app`:

- Its stale Screen Recording entry was removed and the installed app was re-added.
- Re-adding the existing Accessibility entry initially left the app reporting Accessibility Off.
  `tccutil reset Accessibility com.linhui.huidict` removed only HuiDict's stale record; re-adding
  the installed app then made its Permissions pane report both permissions On.
- After quitting and reopening the same build, macOS accepted the certificate-based requirement
  with status `0` and reported `Allowed (System Set)` for both `kTCCServiceAccessibility` and
  `kTCCServiceScreenCapture` in the new process. Repeated capture permission checks were allowed.
- The previous build's code-hash requirement had failed with status `-67050`. The new process
  no longer depends on that requirement. Other apps' permission entries were left unchanged.

This verifies the running app's effective permissions and their persistence across a normal
restart. The global shortcut and Option-hover gesture were not manually repeated in this repair
check. Keep the Signing folder for subsequent updates; replacing the certificate requires
refreshing HuiDict's permission entries again.

Apple documents compatible app identity and permission sharing in
[TN3127](https://developer.apple.com/documentation/technotes/tn3127-inside-code-signing-requirements).
