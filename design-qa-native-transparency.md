# Liquid Glass design QA

final result: passed

## Findings

**Resolved P1 — transparency changed tint but hid reading details at both endpoints.** Hui's
latest screenshots show a white plate at 0% and a gray plate at 100%, with little background detail.
The combined source/implementation comparison below shows those images with the installed fix.
`LookupGlassSurface` now adjusts the native background contribution and neutral wash separately
from the opaque foreground. The focused comparison confirms background letters passing through at
100%; a color change alone no longer establishes transparency. No actionable P0/P1/P2 findings
remain for this transparency correction in the captured states.

## Source and implementation

- Source visual truth: Hui's supplied `latest` screenshots, originally 323 × 298 and 316 × 287
  pixels. Card crops are [reported 0%](docs/liquid-glass-reported-0.png), 300 × 271, and
  [reported 100%](docs/liquid-glass-reported-100.png), 301 × 271. Original display density is unknown.
- Material direction: [Apple Control Center reference](docs/liquid-glass-control-center-reference.png),
  285 × 287 pixels, and [selected dictionary design](docs/liquid-glass-design.png), 1487 × 1058.
  Different control shapes, content, and backdrops are not pixel-match targets for this fix.
- Rendered implementation: installed HuiDict build `2026.1005.155745`,
  [actual card at saved 46%](docs/liquid-glass-popup.png), 320 × 345 pixels including its shadow margin.
  Native viewport: 320 × 345 macOS points at 1 pixel per point. There is no CSS viewport or browser.
- State: real `latest` dictionary-service lookup, `Form of late`, normal translation without a
  captured sentence, light app appearance, inactive app, non-key card. The supplied screenshots use
  contextual Chinese definitions; the diagnostic's normal lookup has longer English alternatives.
  This dynamic-content difference changes height and wrapping. The controlled white reading page
  also differs from Hui's live page. Within each endpoint pair, content and backdrop are the same.
- [Full source and implementation comparison](docs/liquid-glass-transmission-comparison.png),
  680 × 720 pixels. Images are normalized to 300 pixels wide with proportional height. Native
  captures are downsampled from 320 pixels; the source 100% crop is downsampled from 301 pixels.
- [Installed 0%, 55%, and 100%](docs/liquid-glass-popup-transparency.png), 1040 × 415, compares native
  captures without rescaling. The [dark page](docs/liquid-glass-popup-dark.png) checks the same light
  card at maximum transparency, not dark app appearance.
- [Focused detail transmission](docs/liquid-glass-transmission-detail.png), 1404 × 187, compares the
  same 146 × 38 pixel region of the bare page, 0%, and 100%. It excludes dictionary text and enlarges
  pixels 3× without adding detail. Background letters are absent at 0% and transmitted at 100%.
- [Appearance pane](docs/liquid-glass-appearance.png), 580 × 642 pixels at 1 pixel per point,
  preserves the existing 580 × 642 point window. [Preview endpoints](docs/liquid-glass-settings-optics-transparency.png),
  1280 × 345, compare 0%, saved 46%, and 100%. The 320 × 218 point crops are enlarged proportionally
  to 400 pixels wide. These were captured from the same signed candidate installed above.

## Comparison history

1. **Resolved P2 — Settings sample text stopped above the definitions.** The earlier preview fix
   extends paragraphs across the card region. Historical evidence remains in
   [the compact-card report](design-qa-compact.md) and `docs/liquid-glass-iteration.png`.
2. **Earlier P1 — unfocused lookup opaque while Settings showed glass.** Clearing the SwiftUI
   window backing and supplying visual activity enabled native material without making the card key.
   The subsequent color-band metric accepted a color/luminance shift. Hui's white-page screenshots
   reopened that claim: the metric did not prove detail transmission on ordinary reading content.
3. **Resolved P1 — flat gray edge and tight corners.** The previous iteration added the reflective
   outer edge, inner illumination/shading, and broader continuous corners. Historical evidence remains
   in `docs/liquid-glass-popup-comparison.png` and `docs/liquid-glass-popup-edge-comparison.png`.
   Those older images do not validate current transparency behavior.
4. **Resolved P1 — fixed blur at both slider endpoints.** This iteration separates native glass into
   a background layer whose contribution decreases with transparency. Foreground opacity stays full.
   The installed full/focused comparisons above show reading detail. The diagnostic now compares
   correlation with a bare reading-page reference instead of counting changed luminance pixels.
5. **Resolved P2 — the first revised maximum was too clear for dense/dark pages.** Candidate captures
   in `.build/liquid-glass-transmission-candidate-evidence` showed excess interference. Final endpoints
   retain 55% of the native glass layer and a 20% neutral contrast veil at maximum, plus small local
   foreground shadows. Installed captures retain background detail while separating the bold word,
   definitions, labels, and action. Dense background text remains more visible at maximum; lower
   values provide a quieter reading surface. This is an intentional clarity tradeoff.

## Required fidelity surfaces

| Surface | Review |
| --- | --- |
| Fonts and typography | Existing system family, weights, sizes, line height, hierarchy, pronunciation, and SF Symbols remain. The bold word and blue action are distinct. Longer normal-lookup definitions use existing wrapping/truncation. Local contrast shadows do not fade text and are more visible over the dark page. |
| Spacing and layout | Existing width, padding, groups, continuous corners, rim, and shadow remain. Content determines height, explaining the source-height difference. No clipped controls were found. All six Settings panes settle at 580 points wide without overshoot or top-edge drift. |
| Colors and tokens | 0% is opaque; 100% transmits background letters. Native background and tint contribution use design tokens. Foreground and system blue action retain opacity. Reduce Transparency preserves the opaque branch; Increase Contrast preserves the inner boundary. OS accessibility settings were not changed for capture. |
| Image quality and assets | Production uses live native glass, system text, and SF Symbols. No captured background, generated art, or substitute logo is embedded. PNGs are evidence. Focused enlargement preserves original pixels. The illuminated rim remains a UI surface treatment. |
| Copy and content | Liquid Glass description, percentage, endpoint labels, helper copy, and More meanings retain the approved panel. Actual `latest`, `Form of late`, and real service results appear. Contextual versus normal translation explains content differences. |

## Native validation and delivery

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make local` passed: seven Swift runs
  totaling 2,110 tests and 83 Python tool/reference tests, including ScreenRecordingAccessTests.
  Existing optional-fixture and upstream-bundle guard skips remain; no test failures occurred.
- Installed non-key window 9887 stayed open throughout 18 states: six values on white, colored, and
  dark pages. Every state had `appIsActive: false` and `isKey: false`; Chrome retained focus.
  Saved value `0.4564910239361702` was restored. The first installed capture lost its temporary
  window; an isolated rerun completed all states successfully.
- White-page correlation with the bare backdrop rose from -0.0256 at 0% to 0.4286 at 100%
  (gain 0.4542). The check requires clear correlation above 0.35 and gain above 0.20. Colored and
  dark-page gains were 0.4252 and 0.6412. Correlation measures detail correspondence, not a percentage
  of optical transparency; visual endpoint comparison is also required.
- Settings captured Appearance and Permissions with no evidence problems. All six panes settled
  with the same width, zero overshoot, and zero top-edge drift; the saved preference was restored.
- Signing/update checks passed before atomic installation. Installed host and both XPC service hashes
  matched staging. Three fresh installed permission reports returned the correct bundle, both grants,
  and exit zero. Normal LaunchServices process 23660 had TCC Allowed decisions for Accessibility and
  Screen Recording with HuiDict as the responsible process. Three installed real service lookups
  returned entries. The previous bundle remains available as a reversible rollback copy.

## Residual checks and follow-up polish

Diagnostics change the slider's observable preference; a physical drag is not claimed. User-triggered
selection/image shortcuts, pointer hover, and dark app appearance were not performed in this iteration.
Maximum transparency exposes more background text, so reading comfort over dense pages remains a
useful user check. No exact match to Apple's Control Center optics or adaptive foreground is claimed.

## Implementation checklist

- [x] Open source and installed captures together with normalized scale.
- [x] Resolve tint-only transparency and inspect focused background detail.
- [x] Check foreground, intermediate values, Settings preview, and saved preference.
- [x] Pass required tests and preserve signing during reversible installation.
- [x] Verify normal-launch grants, unfocused installed card, and dictionary service.
