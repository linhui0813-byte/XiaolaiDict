# Liquid Glass design QA

final result: passed

## Findings

The earlier pass accepted backdrop blur and opacity response without checking the reflective
edge. Hui's live `implement` screenshot reopened that acceptance. The revised native card now
has a bright curved outer edge, a softer inner reflection, and a shaded inner edge. The focused
comparison shows these features at the top-left corner where the previous card was a flat plate.
No actionable P0, P1, or P2 differences remain in the captured states against the material target.
This is a comparison of glass treatment, not a claim that dictionary content is pixel-identical
to Apple's Control Center.

## Source and implementation

- Source visual truth: [Hui's Apple Control Center reference](docs/liquid-glass-control-center-reference.png),
  a 285 × 287 pixel crop of the supplied 592 × 998 screenshot. Only Bluetooth and AirDrop are retained;
  the crop omits the personal Wi-Fi name and activity banner. Original capture density is unknown.
- Earlier card design: [selected settings mockup](docs/liquid-glass-design.png), 1487 × 1058 pixels.
  Its dictionary layout and dark foreground remain the content target.
- Implementation: [actual floating card](docs/liquid-glass-popup.png), build `2026.1005.152146`,
  320 × 299 pixels at 1 pixel per macOS point, including its asymmetric shadow margin.
  This is a real `refused` lookup through the app's dictionary service, with its normal word translation.
- State: light app appearance, saved transparency approximately 75%, app inactive, window not key.
  The diagnostic backdrop is the app's own reading window, not an image embedded in the product.
  The backdrop does not represent the exact content behind Control Center in Hui's screenshot.
- [Full material comparison](docs/liquid-glass-popup-comparison.png), 1050 × 390 pixels, contains the
  Apple material reference, previous real card at 100%, and revised real card at 100% together.
  The previous capture is installed build `2026.1005.145902`; both native card captures are 320 × 299
  pixels, use the same reading backdrop, and show the same dictionary/translation content. A new
  attempt to capture that old build returned `windowMissing`, so the previously verified capture
  is used and no fresh baseline-run success is claimed.
- [Focused edge comparison](docs/liquid-glass-popup-edge-comparison.png), 900 × 340 pixels, enlarges
  actual 100 × 100 pixel corner crops to 285 × 285 pixels. This makes rim illumination and inner depth
  visible; enlargement adds no rendering detail. The capsule and dictionary corners have different
  geometry, so their radii are not judged by a pixel difference.
- [Appearance pane](docs/liquid-glass-appearance.png), 1160 × 1284 pixels at 2 pixels per point in the
  existing 580 × 642 point window, uses the same revised compact-card material and the saved 75% value.
  Its chrome and slider were inactive in this capture. [Focused preview endpoints](docs/liquid-glass-settings-optics-transparency.png)
  normalize the 2x card crops to 400 pixels wide and show 0%, 75%, and 100% together.
- [Pop-up opacity states](docs/liquid-glass-popup-transparency.png), 1380 × 355 pixels, include 0%,
  55%, saved 75%, and 100% without rescaling the native captures. [Dark reading backdrop](docs/liquid-glass-popup-dark.png)
  checks the same light-appearance card at maximum transparency. There is no CSS viewport or browser.

## Comparison history

1. **Resolved P2 — the original Settings backdrop stopped above the definitions.** The preview now
   continues sample reading paragraphs across the full card region. Earlier layout evidence remains
   in [the compact-card report](design-qa-compact.md) and `docs/liquid-glass-iteration.png`.
2. **Resolved P1 — the actual unfocused pop-up was opaque despite the Settings preview.** The previous
   fix explicitly supplied the public `appearsActive` value and cleared the SwiftUI window backing.
   Its real non-key-window report verified opacity changes. That established functioning material,
   but the later live screenshot showed that its optical quality still needed work.
3. **Resolved P1 — a gray outline and narrow corners made the glass look flat.** Hui's Control Center
   screenshot became the explicit optical target. An isolated native non-key-window experiment
   compared background-only clear glass, whole-content clear/regular glass, native tint, and AppKit
   `contentView` hosting. Switching the native style alone still left the edge flat. The production
   modifier now keeps foreground and wash in the same native glass hierarchy, removes the gray
   outline, adds a graduated outer reflection plus an inner illuminated/shaded edge, and increases
   lookup corner radius from 1.5 to 2.5 em. The surface opacity still changes only the neutral wash.
   The full and focused comparisons above show the revised real card, not only the experiment.

## Required fidelity surfaces

| Surface | Review |
| --- | --- |
| Fonts and typography | Existing system fonts, bold word, pronunciation, part-of-speech labels, definitions, and blue action are preserved. Foreground now receives the glass hierarchy's visual treatment. Text stays sharp at each opacity; the English definition retains its existing compact truncation and More meanings action. |
| Spacing and layout | Existing card width, padding, content height, settings layout, and shadow margins are preserved. Broader continuous corners support the reflective rim without clipping content. All six Settings panes settle at the existing 580-point width without overshoot or top-edge drift. |
| Colors and tokens | Live native clear glass continues to sample and blur the backdrop. Outer reflection, inner shading, and corner geometry use design tokens. Opacity changes only the neutral wash. The outer edge is strongest along the illuminated curves rather than a uniform gray outline. Reduce Transparency retains its opaque branch; Increase Contrast adds a distinct inner boundary. |
| Image quality and assets | Native live text and SF Symbols are used. No screenshot or generated background is embedded in the card. The reference and implementation PNGs are evidence only. Bright specular edges are vector UI treatment, over the native material. |
| Copy and content | The Liquid Glass description, slider, percentage, endpoint labels, and helper text retain the approved adjustment panel. Real lookup text, pronunciation, dictionary service, translation, and More meanings flow retain their existing behavior. |

## Native validation

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make local` passed: seven Swift test
  runs totaling 2,109 tests and 83 Python tool/reference tests. Existing optional-fixture and
  upstream-bundle guard skips remain; this build produces HuiDict. No test failures were reported.
- The installed pop-up used window 9535 throughout 0%, 55%, saved 75%, and 100%. Every state
  had `isKey: false` and `appIsActive: false`; the frontmost application remained unchanged.
  Changing the same observable preference used by the slider from 0% to 100% changed 98.54% of
  measured interior pixels by more than 24 luminance levels. That establishes opacity response;
  it does not substitute for the visual edge comparison.
- The saved value `0.7479014295212766` was restored after both native diagnostics.
- The Settings report captured Appearance and Permissions with no evidence errors. All six panes
  settled, preserved width, and had zero top-edge drift and zero overshoot.
- The candidate passed signing/update compatibility and strict bundle verification before replacement.
  The installed bundle retains the host and both service hashes verified at staging. Three fresh
  installed permission-report processes returned `com.linhui.huidict`, both grants, and exit zero.
  Normal LaunchServices process 10865 had macOS TCC Allowed decisions for Accessibility and
  Screen Recording, with HuiDict as the subject. Three installed real service lookups returned entries.
  The previous bundle is retained at the existing Applications location as a rollback copy.

## Intentional differences and residual checks

Control Center is a grid of controls with white foreground, capsule shapes, and a different backdrop.
The dictionary retains the selected mockup's dark reading text, its compact layout, and its blue action.
Its public native glass supplies blur and refraction; the added rim supplies the visible large-sheet
edge. The subdued in-window reading preview shows diffuse backdrop color at high transparency rather
than readable background text. The actual floating-window captures demonstrate the clearer material
response over distinct reading colors. These are expected state and content differences.

The diagnostics mutate the slider's observable preference; a physical slider drag is not claimed.
Dark app appearance, pointer hover, and user-triggered selection/image shortcut gestures were not
performed in this optical QA run. No OS accessibility preferences were changed for testing.

## Implementation checklist

- [x] Compare reference and real implementation together, including focused rim crops.
- [x] Resolve the flat-edge mismatch and recapture the actual non-key card.
- [x] Check Settings layout, preview, opacity endpoints, and preservation of the saved setting.
- [x] Pass required tests and preserve signing compatibility before installation.
- [x] Verify installed normal-launch grants and real service lookups after deployment.
