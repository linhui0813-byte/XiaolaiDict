# AGENTS.md

- If there's any change, automatically commit, push, and deploy for me.

HuiDict is this fork's local macOS dictionary app. Preserve its existing permission identity on every update.

## Build and test

- Build HuiDict with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make local`.
- Run `make local-test` for Swift changes and `make test-tools` for changes under `Tools/`.
- App permission checks live in `Sources/XiaolaiDictUI/Permissions.swift`; automatic capture requests
  are owned by `Sources/XiaolaiDict/ScreenRecordingAccess.swift`.
- Local signing and compatibility checks live in `Tools/local-signing.py` and `Tools/build-bundle.sh`.

## Preserve permissions when updating HuiDict

1. **Reuse the original local certificate.** Keep `~/Library/Application Support/HuiDict/Signing`
   outside the repository and retain it across updates and build cleanup. Credentials stay private.
   If it is missing or unusable, recover the original folder and stop deployment until it works.
   `setup` is for first installation; an existing certificate-signed app requires identity recovery.
2. **Keep the app identity and install path fixed.** Update `~/Applications/HuiDict.app` with bundle
   identifier `com.linhui.huidict`. Preserve the certificate-based designated requirement (the rule
   macOS uses to recognize the same app). A changing executable hash is normal; a changing signing
   requirement invalidates saved permissions. Use the persistent signer required by `make local`.
3. **Check compatibility before replacing the app.** Run
   `python3 Tools/local-signing.py check-update .build/HuiDict.app` and require exit status zero.
   The build also checks the installed app and previous bundle before publication. If a check fails,
   retain the current app and report the identity mismatch; permission resets are not a workaround.
   Run signing verification with access to the existing local keychain. If the sandbox blocks that
   access, retry the same check outside the sandbox while keeping certificate trust unchanged.
4. **Install reversibly.** Keep a rollback copy of the installed bundle, verify the new bundle's
   signature and host hash, and replace it atomically at the existing path. Launch the installed copy.
5. **Verify effective grants after the update and restart.** Run
   `~/Applications/HuiDict.app/Contents/MacOS/HuiDict --permission-report` three times in fresh
   processes with window-server access; require JSON `bundle` equal to `com.linhui.huidict` and
   exit status zero. This diagnostic never asks for access, but a terminal can lend its permissions.
   Also launch HuiDict normally and require its own Permissions pane to show both On, or TCC
   decisions of Allowed with HuiDict as the responsible process, after updating and restarting.
   A terminal report or Settings switch alone is insufficient. Check repeated selection and image
   lookups; report separately when the user-triggered gesture check has not been performed.
6. **Keep status checks silent and permission requests bounded.** Use the shared permission probe:
   an ungranted preflight must skip ScreenCaptureKit, and repeated/concurrent lookups share at most
   one automatic Screen Recording request per process. Run `ScreenRecordingAccessTests` when changing
   this behavior. Retain strict signatures and exact code-hash checks between the app and its services.

For diagnosis and the completed one-time migration, see [the permission repair](docs/permission-repair.md).
Normal updates preserve grants; resetting macOS permissions is a repair step for a diagnosed stale
identity, not part of the update workflow. macOS may still request consent after the user revokes
access, the certificate is replaced, or macOS changes its permission policy.
