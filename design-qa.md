# Liquid Glass design QA

final result: passed

Hui's live screenshots reopened the review: the Settings preview was insufficient evidence for
the actual unfocused lookup. The installed fix now responds visibly in the same unfocused window,
including over a dark reading background. No actionable P0, P1, or P2 findings remain in these states.
Earlier compact-card validation is preserved in [the previous QA report](design-qa-compact.md).

## Comparison target and evidence

- Source visual truth: [selected design](docs/liquid-glass-design.png), 1487 × 1058 pixels.
- Current implementation: [real floating lookup](docs/liquid-glass-popup.png), installed build
  `2026.1005.145902`, 320 × 299 pixels at 1 pixel per macOS point, including its shadow margin.
  State: light app appearance, 55% transparency, actual `refused` dictionary lookup, app inactive,
  window not key. [Current combined comparison](docs/liquid-glass-popup-comparison.png) places the
  selected card region, Hui's reported opaque card, and the fixed card together. Card crops are
  normalized to 530 pixels wide. The reported card is `Appearance`; dynamic content differs.
- [Actual pop-up opacity comparison](docs/liquid-glass-popup-transparency.png) contains full native
  window captures at 0%, 55%, and 100%. [Dark-backdrop capture](docs/liquid-glass-popup-dark.png)
  checks maximum transparency over dark reading content while the app itself remains in light mode.
  These supersede the initial Settings-only material verification below.
- The following Appearance-pane evidence records the initial layout review, build `2026.1005.140701`:
- Implementation: [installed Appearance pane](docs/liquid-glass-appearance.png), build
  `2026.1005.140701`, 580 × 642 pixels at 1 pixel per macOS point.
- Viewport: the existing 580 × 642 point native settings window. There is no CSS viewport or browser.
- State: light appearance, saved transparency 55%, sample `refused` lookup. The captured window's
  chrome and slider render in the native inactive state; pointer and keyboard focus were not tested.
- [Full-view comparison](docs/liquid-glass-comparison.png): source and implementation together,
  each resized to 680 pixels wide with its aspect ratio preserved. The source is a conceptual
  settings mockup rather than a screenshot with a known point density, so this is a composition
  comparison, not a pixel difference measurement.
- [Focused card comparison](docs/liquid-glass-card-comparison.png): actual card regions from both
  images normalized to the same 620 pixel width. Enlargement of the 1x native capture exposes
  its original pixel density rather than additional rendering detail.
- [Transparency endpoints](docs/liquid-glass-transparency.png): 0%, 55%, and 100% captures of the
  installed pane, using the same actual compact-card renderer as lookup windows.

## Findings and comparison history

1. **Resolved P2 — preview backdrop ended above the definitions.** The initial native preview
   contained only one short paragraph, leaving most of the glass over a flat field. The selected
   design contains reading text behind the entire card, making the material easier to judge.
   `LookupGlassPreview` now continues the sample reading text through the preview using
   `Token.Glass.previewParagraphs`. [Before and after evidence](docs/liquid-glass-iteration.png)
   includes the source, build `2026.1005.140259`, and final build `2026.1005.140701` in one input.
   The earlier 1160 × 1284 pixel capture was at 2x density; both native captures are normalized
   to the same width for this comparison. The final backdrop covers the card's content region.
2. **Expected native adaptations.** The existing 580-point settings window uses its standard
   six-pane toolbar rather than the mockup's standalone Appearance heading. The card keeps its
   existing compact type sizes and combines meanings with the same part of speech. The native
   material responds to its background. The sample backdrop uses reading text on a neutral accent
   wash rather than the reference's decorative desktop wallpaper. These preserve the requested
   glass treatment and adjustment layout without replacing existing app content with a raster mockup.
3. **Resolved P1 — actual unfocused pop-up stayed opaque and the slider gave no visible feedback.**
   Hui's live `Appearance` screenshot shows a flat gray surface despite the transparent Settings
   preview. The earlier pass did not test the actual non-key window and incorrectly accepted its
   dull material as a native adaptation. `LookupGlassSurface` now explicitly supplies the public
   `appearsActive` environment value to the glass background, and `LookupPanelSceneView` clears its
   SwiftUI window backing. This changes the material without making the window key or activating
   the app. In the installed build, all three captures use window 9228 with `isKey: false` and
   `appIsActive: false`. Changing the same observable preference as the slider from 0% to 100%
   changed 98.17% of interior pixels by more than 24 luminance levels; rounded corners and shadow
   margins were excluded. The frontmost app stayed unchanged and the saved 100% value was restored.
   The current combined comparison, full-window opacity comparison, and dark-backdrop capture
   provide the post-fix evidence. The neutral wash varies; foreground text is not faded.

## Required fidelity surfaces

| Surface | Review |
| --- | --- |
| Fonts and typography | Native system UI fonts retain the bold word, lighter pronunciation, readable meanings, and blue action hierarchy. Reading text uses the serif system font. Labels and percentage fit; no truncation or overlapping text is visible. |
| Spacing and layout | Liquid Glass description sits left of the preview; percentage, slider, endpoint labels, and helper text sit below it. The card has rounded corners, divider, balanced padding, and a shadow. All controls fit the existing window. All six panes settle at one width with no overshoot or top-edge drift. |
| Colors and tokens | The actual unfocused window now shows blurred backdrop colors. Its 0/55/100 captures show progressively more background; primary text stays legible over colored and dark reading content. The Settings slider retains native active/inactive styling. The saved preference controls only the wash. Reduce Transparency produces an opaque fallback; Increase Contrast strengthens the edge. |
| Image quality and assets | The implementation uses live native text, SF Symbols, and the actual card renderer. No screenshot is embedded as UI. Saved screenshots are lossless PNG evidence. The source's decorative wallpaper is treated as demonstration context, not a required app asset. |
| Copy and content | Liquid Glass, Transparency, percentage, More opaque, Clearer, and helper text follow the reference. The sample remains `refused`; its definitions follow HuiDict's existing grouping. “More meanings” retains its real lookup action. |

## Validation and limits

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make local` passed: seven Swift test
  runs totaling 2,109 tests reported success, plus 83 tool tests for the final fix. Optional
  dictionary fixtures and the upstream `XiaolaiDict.app` bundle
  verification suite were skipped by their existing guards; this change builds `HuiDict.app`.
- Four new tests cover the default, saved values across relaunch, invalid input, continuous
  surface opacity, and Reduce Transparency. Existing layout tests still verify bottom padding.
- Installed `--settings-report` after the rendering fix: all six panes settled, 580-point width
  retained, and no screenshot failures. The saved preference was restored.
- The opt-in `--panel-report` glass check captures only HuiDict's real lookup and its own backdrop.
  It verified live updates in the same window, unchanged focus, and restoration of the saved value.
  It also captured a dark reading background at maximum transparency. The native material's rim
  is subtler than the reference's painted highlight; the actual backdrop determines its coloration.
- Three fresh installed `--permission-report` processes returned `com.linhui.huidict`, both grants,
  and exit status zero. The app's own Permissions pane showed both On. After a normal restart,
  macOS TCC logged Allowed for Accessibility and Screen Capture with HuiDict's installed executable
  as the responsible process. Signing compatibility, strict signatures, and host/service hashes
  were verified; the previous installed bundle remains available as a rollback.
- Three repeated `refused` lookups returned dictionary entries through the signed XPC service.
- Pointer dragging, keyboard adjustment, repeated selection/image lookup gestures, dark-mode
  app rendering, and a visual check with accessibility settings enabled remain unperformed. The user
  deferred the draggable preview test until the demo was complete. Programmatic value changes
  and unit tests do not substitute for those hands-on checks.

## Implementation checklist

- [x] Apply the shared native glass surface to lookup cards and the actual-card preview.
- [x] Add a saved, continuous transparency slider in Settings → Appearance.
- [x] Preserve foreground readability and provide the accessibility fallback.
- [x] Compare the source and final native captures together, including the resolved preview issue.
- [x] Build, test, install reversibly, and verify signing, permissions, and dictionary services.
- [ ] Perform the deferred pointer/keyboard and selection/image gesture checks in the installed app.
