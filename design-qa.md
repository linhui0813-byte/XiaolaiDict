# Native Liquefy UI integration QA

final result: needs review

The native integration is built and installed on `feature/liquefy-ui-trial`.
The build, signatures, update identity, permission reports, and dictionary
service checks pass. Live optical and gesture verification remains pending:
the desktop is locked, both displays are asleep, and ScreenCaptureKit returns
an empty display list. This report does not claim a completed visual review.
The prior browser result is retained in [preview QA](design-qa-liquefy-preview.md).

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
- Native diagnostic runtime reported actual library version `1.0.0`, lens map
  present, rim shader present, and the saved transparency preference delivered
  to JavaScript. No backdrop frames arrived while the desktop was locked.
- Both direct and LaunchServices native diagnostic launches encountered the
  same missing capture display. A separate silent AppKit/ScreenCaptureKit probe
  reported `CGSSessionScreenIsLocked = 1`, display asleep, and zero shareable
  displays. This distinguishes the current environmental block from a claim
  that the card's optical rendering was visually verified.
- Three fresh installed `--permission-report` processes returned exit zero,
  `bundle = com.linhui.huidict`, and both grants present, including three new
  processes after restarting the normal app. Normal app TCC decisions
  independently allowed Accessibility and Screen Recording for HuiDict itself;
  terminal-launched reports alone are not the evidence for the app's own grants.
- Three installed dictionary lookups of `set` returned `entries`.

## Installation

Installed build: `2026.1006.21702` at `~/Applications/HuiDict.app`.
The update used the original persistent certificate and bundle identifier
`com.linhui.huidict`. The bundle was installed with an atomic exchange; the old
build is retained as
`~/Applications/HuiDict.rollback-2026.1005.155745-liquefy-20261006T022328Z.app`.
The normal installed app is left running. No permissions were reset.

Local evidence is retained in `.build/liquefy-native-build.log`,
`.build/liquefy-native-qa-report.json`, `.build/liquefy-native-ls-report.json`,
`.build/liquefy-native-install.json`, `.build/liquefy-native-permission-reports.json`,
`.build/liquefy-native-own-tcc.log`, and
`.build/liquefy-native-installed-lookups.jsonl`.

## Review still required

An unlocked desktop is required to verify live frame delivery, the actual 0%
and 100% floating-card transmission over light/colored/dark reading pages, the
Appearance slider and sample renderer, detailed-card resizing, and repeated
selection/image lookup gestures. No native screenshot from this integration
is presented as accepted design evidence yet. The prior browser captures apply
only to the browser preview. Audio output and sustained CPU/GPU usage have not
been measured for this native integration.

To collect the native card evidence after unlocking:

```sh
HUIDICT_LOOKUP_GLASS_EVIDENCE_DIRECTORY="$PWD/.build/liquefy-native-qa" \
  ~/Applications/HuiDict.app/Contents/MacOS/HuiDict --panel-report
```

The report requires the real renderer to receive a backdrop before measuring
transmission. It changes the same persisted preference as the slider, restores
its original value afterward, and captures only the app's own card and test page.
