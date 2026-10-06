# Native Liquefy UI integration QA

final result: pass

The native integration is built and installed on `feature/liquefy-ui-trial`.
The build, signatures, update identity, permission reports, live backdrop,
transparency endpoints, dark-page contrast, and Appearance preview checks pass.
This verdict covers native rendering and the shared preference. Pointer dragging
of the slider, detailed-card controls, and physical shortcut/image-hover gestures
remain unverified. Hui's visual acceptance is separate from these checks.
The prior browser result is retained in [preview QA](design-qa-liquefy-preview.md).

[Native transparency comparison](docs/liquefy-native-transparency.png),
[installed Appearance pane](docs/liquefy-native-appearance.png),
[dark-page card](docs/liquefy-native-dark.png), and
[installed Permissions pane](docs/liquefy-native-permissions.png) are actual
native screenshots of the app's own test content, not generated mockups.

## Implementation

The native lookup background now embeds the actual `@liquefy-ui/react` 1.0.0
`LiquidGlass` and `LiquefyProvider`. Its offline adapter imports the actual
`@liquefy-ui/core` 1.0.0 `createLensMap`. The inspected upstream repository is
[liquefy-ui/liquefy-ui](https://github.com/liquefy-ui/liquefy-ui), source commit
`96af8d8f9757420f60c6d085aa0b49bdaa8a0ad6`.

Upstream's SVG displacement in `backdrop-filter` is Chromium-only. The adapter
samples captured pixels with that same lens map in WebGL 2 inside WKWebView.
The upstream component still supplies the rim shader, veil, edge, and surface
reflections. This adapts Liquefy's rendering; it is not Apple's proprietary
Liquid Glass implementation.

ScreenCaptureKit supplies the rectangle behind the visible card, excluding
the lookup window itself. Frames remain in memory, refresh at up to six frames
per second, and never leave the app. The existing silent permission probe gates
capture; no new consent request is added. The capture session stops when the
card closes. Native material remains available until a lens and backdrop frame
are ready. The Appearance preview renders its own sample page into memory and
uses the same renderer and persisted transparency preference.

Native text, pronunciation, Close, Dictionary, More meanings, scrolling, and
the non-key lookup window remain in SwiftUI. Transparency changes the optical
background independently of the foreground. Reduce Transparency uses the opaque
native surface. Reduce Motion suppresses the animated rim. Mostly clear cards
adapt foreground colors to the captured background's luminance.

Live review corrected two renderer issues. The backdrop texture now enables
mipmap filtering so its blur blends text smoothly instead of drawing repeated
sharp copies. Foreground contrast now uses the average of a 16 by 16 sample
instead of a single resized pixel that could pick a white glyph on a dark page.
The complete background is clipped to the native card shape, including the
Appearance preview's corners.

## Verification completed

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make local` passed
  all 2,112 Swift tests and 87 tool/reference tests. The test-defaults cleanup
  completed with no abandoned preferences returning.
- The new region tests cover top-left capture coordinates on a second display
  with negative vertical origin and reject invalid/off-screen geometry.
- The asset tests reject modified payloads, changed source without regeneration,
  and missing copyright notices. The native build verifies the source/payload
  manifest before signing and includes licenses for every rendered package.
- Strict signatures, component host hashes, and compatibility with the installed
  certificate-based signing requirement passed before and after installation.
- The installed native diagnostic reported actual library version `1.0.0`,
  a lens map and rim shader, a running capture stream, and delivered frames.
  All 18 readings were ready and received the requested transparency value.
  The same open native card changed across 0%, 25%, 55%, the saved 73%, 75%,
  and 100% over Paper, Colored, and Dark pages. The original preference was restored.
- At 0% the body is opaque. At 100% the live page is transmitted through a
  softened and refracted background. The test page is ordered directly below
  the card so the screenshot reference and the live stream see the same page.
  Correlation of visible page structure at the clear endpoint was 0.730 for
  Paper, 0.880 for Colored, and 0.557 for Dark; gains over opaque were 0.795,
  0.953, and 0.510. The unchanged thresholds of 0.35 correlation and 0.20 gain
  pass for every page. A two-point smoothing of both readings measures the
  structure that glass should preserve; raw sharp-pixel measurements are also
  retained, because blur intentionally removes fine glyph detail.
- Dark-page frames correctly switch the mostly clear card to light foreground
  text. All optical readings kept the card non-key and the app inactive; the
  frontmost application was unchanged throughout the installed optical run.
- The installed Settings diagnostic captured opaque and clear Appearance
  previews and both permission grants On. Every pane settled, the window kept
  one width, and pane transitions had no reversal or overshoot. These captures
  change the shared preference programmatically; they do not prove pointer dragging.
- A separate card-click diagnostic kept the window non-key but activated HuiDict.
  Running the same diagnostic against the signed pre-integration rollback
  (`2026.1005.155745`) produced the same activation, frame, and menu behavior.
  This is an existing focus limitation, not a Liquefy regression. The card
  survived the click and the diagnostic's menu selection in both builds.
- Three fresh installed `--permission-report` processes returned exit zero,
  `bundle = com.linhui.huidict`, and both grants present, including three new
  processes after restarting the normal app. Normal app TCC decisions
  independently allowed Accessibility and Screen Recording for HuiDict itself;
  terminal-launched reports alone are not the evidence for the app's own grants.
- Three installed dictionary lookups of `set` returned `entries`.

## Installation

Installed build: `2026.1006.94610` at `~/Applications/HuiDict.app`.
The update used the original persistent certificate and bundle identifier
`com.linhui.huidict`. The bundle was installed with an atomic exchange; the old
build is retained as
`~/Applications/HuiDict.rollback-2026.1006.21702-liquefy-20261006T094719Z.app`.
The earlier pre-integration rollback is also retained at
`~/Applications/HuiDict.rollback-2026.1005.155745-liquefy-20261006T022328Z.app`.
The normal installed app is left running. No permissions were reset.

Local evidence is retained in `.build/liquefy-native-build.log`,
`.build/liquefy-native-qa-report.json`, `.build/liquefy-native-settings-report.json`,
`.build/liquefy-native-install.json`, `.build/liquefy-native-permission-reports.json`,
`.build/liquefy-native-own-tcc-decisions.log`, and
`.build/liquefy-native-installed-lookups.jsonl`.
The focus comparison is in `.build/liquefy-native-controls-report.json` and
`.build/liquefy-native-controls-baseline.json`.

## Review still required

End-to-end pointer dragging of the Appearance slider, detailed-card resizing
and controls, and repeated physical selection/image lookup gestures still need
review. The automation could not attach to the normal menu-only app without a
visible window. Its generated shortcut changed the temporary TextEdit document
instead of completing a valid selection lookup; those attempts are not counted
as successful gesture checks. No user document was changed.
Audio output and sustained CPU/GPU usage have not been measured for this native
integration. The prior browser captures apply only to the browser preview.

To repeat the native optical check on an unlocked desktop:

```sh
HUIDICT_LOOKUP_GLASS_EVIDENCE_DIRECTORY="$PWD/.build/liquefy-native-qa" \
  ~/Applications/HuiDict.app/Contents/MacOS/HuiDict --panel-report
```

The report requires the real renderer to receive a backdrop before measuring
transmission. It changes the same persisted preference as the slider, restores
its original value afterward, and captures only the app's own card and test page.
