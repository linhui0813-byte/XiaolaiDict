# Liquid Glass design QA

final result: passed

No actionable P0, P1, or P2 visual findings remain in the reviewed light Appearance pane.
This is a native macOS adaptation of the selected mockup, with the existing card typography,
meaning grouping, and settings window dimensions retained.
Earlier compact-card validation is preserved in [the previous QA report](design-qa-compact.md).

## Comparison target and evidence

- Source visual truth: [selected design](docs/liquid-glass-design.png), 1487 × 1058 pixels.
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
   material responds to background and window state; its rim is subtler than the painted white
   highlight in the generated reference. The sample backdrop uses reading text on a neutral accent
   wash rather than the reference's decorative desktop wallpaper. These preserve the requested
   glass treatment and adjustment layout without replacing existing app content with a raster mockup.

## Required fidelity surfaces

| Surface | Review |
| --- | --- |
| Fonts and typography | Native system UI fonts retain the bold word, lighter pronunciation, readable meanings, and blue action hierarchy. Reading text uses the serif system font. Labels and percentage fit; no truncation or overlapping text is visible. |
| Spacing and layout | Liquid Glass description sits left of the preview; percentage, slider, endpoint labels, and helper text sit below it. The card has rounded corners, divider, balanced padding, and a shadow. All controls fit the existing window. All six panes settle at one width with no overshoot or top-edge drift. |
| Colors and tokens | Shared native clear glass plus a continuous neutral wash replaces the opaque lookup surface. The 0/55/100 captures show progressively more background; foreground content stays legible. The inactive slider's gray track is a native state difference from the blue reference. Reduce Transparency produces an opaque fallback; Increase Contrast strengthens the edge. |
| Image quality and assets | The implementation uses live native text, SF Symbols, and the actual card renderer. No screenshot is embedded as UI. Saved screenshots are lossless PNG evidence. The source's decorative wallpaper is treated as demonstration context, not a required app asset. |
| Copy and content | Liquid Glass, Transparency, percentage, More opaque, Clearer, and helper text follow the reference. The sample remains `refused`; its definitions follow HuiDict's existing grouping. “More meanings” retains its real lookup action. |

## Validation and limits

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make local` passed: seven Swift test
  runs totaling 2,109 tests reported success, plus 83 tool tests. `make local-test` passed again
  after installation. Optional dictionary fixtures and the upstream `XiaolaiDict.app` bundle
  verification suite were skipped by their existing guards; this change builds `HuiDict.app`.
- Four new tests cover the default, saved values across relaunch, invalid input, continuous
  surface opacity, and Reduce Transparency. Existing layout tests still verify bottom padding.
- Installed `--settings-report` through LaunchServices: all six panes settled, dictionary service
  answered, 580-point width retained, and no screenshot failures. The original 55% value was restored.
- Three fresh installed `--permission-report` processes returned `com.linhui.huidict`, both grants,
  and exit status zero. The app's own Permissions pane showed both On. After a normal restart,
  macOS TCC logged Allowed for Accessibility and Screen Capture with HuiDict's installed executable
  as the responsible process. Signing compatibility, strict signatures, and host/service hashes
  were verified; the previous installed bundle remains available as a rollback.
- Three repeated `refused` lookups returned dictionary entries through the signed XPC service.
- Pointer dragging, keyboard adjustment, repeated selection/image lookup gestures, dark-mode
  rendering, and a visual check with accessibility settings enabled remain unperformed. The user
  deferred the draggable preview test until the demo was complete. Programmatic value changes
  and unit tests do not substitute for those hands-on checks.

## Implementation checklist

- [x] Apply the shared native glass surface to lookup cards and the actual-card preview.
- [x] Add a saved, continuous transparency slider in Settings → Appearance.
- [x] Preserve foreground readability and provide the accessibility fallback.
- [x] Compare the source and final native captures together, including the resolved preview issue.
- [x] Build, test, install reversibly, and verify signing, permissions, and dictionary services.
- [ ] Perform the deferred pointer/keyboard and selection/image gesture checks in the installed app.
