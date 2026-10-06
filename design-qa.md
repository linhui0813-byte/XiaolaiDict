# Liquefy UI trial design QA

final result: passed

This result covers the browser trial on `feature/liquefy-ui-trial`. It does not
claim native integration or exact reproduction of Apple's Liquid Glass. The
[previous native transparency QA](design-qa-native-transparency.md) is preserved
as historical evidence for the unchanged app.

## Findings and fixes

- **Resolved P1 — the first card remained a frosted plate.** The first browser
  render used Liquefy's `GlassCard`, whose light-theme data-surface stylesheet
  adds 7 px of blur. Disabling provider motion also prevented its shader controller
  from drawing highlights. The revised implementation uses the actual package's
  `LiquidGlass`, 1.5–6.5 px frost, and a static non-interactive card with the shader
  controller enabled. The combined material comparison shows the thinner surface,
  refracted reading details, and illuminated boundary after the change.
- **Resolved P1 — the compact viewport clipped the card's right-hand controls.**
  The first 390 px capture shows the search action and submit button cut off.
  The grid now has a `minmax(0, 1fr)` track, the card allows shrinking, and the
  stage grows with expanded content. The matched revised capture shows all
  controls, definitions, extra meanings, and error copy within the stage.
- **Resolved P2 — pronunciation had a generic play icon.** A Lucide speaker
  icon replaces it, with stroke weight and size aligned to the library's search
  and close icons. These are real library assets, not handcrafted SVG substitutes.

No actionable P0/P1/P2 issue remains in the captured trial states. Maximum
transparency deliberately transmits more background text; lower settings give
stronger separation. That tradeoff is visible in the endpoint comparison and
is not evidence of an Apple-equivalent native material.

## Source and rendered evidence

- Source layout: [selected Appearance design](docs/liquid-glass-design.png),
  1487 × 1058 px. Material reference captured from the upstream
  [Card](https://liquefy-ui.com/#/components/card) and
  [Glass](https://liquefy-ui.com/#/components/glass) documentation before building;
  original captures are in `.build/liquefy-qa/source-card.png` and `source-glass.png`.
- Implementation: [actual browser preview](docs/liquefy-ui-trial-preview.png),
  1280 × 900 px. CSS viewport 1280 × 900, device scale 1, PNG 1 px per CSS px.
  Default state: `refused`, color background, 68%, closed search/details.
- [Full comparison](docs/liquefy-ui-trial-comparison.png), 1680 × 461 px, contains
  the selected design, first browser render, and final browser render in one image.
  Source and final use 55%; the first render used its 68% default. Each full
  canvas is proportionally normalized into a 540 px wide region for composition.
- [Focused card comparison](docs/liquefy-ui-trial-material-comparison.png),
  1260 × 356 px, normalizes the 544 × 380 source crop and 404 × 307 browser crops
  into equal 400 px wide slots. Original generated-reference display density is
  unknown; it is an art-direction comparison rather than a pixel-perfect clone.
- [0% and 100%](docs/liquefy-ui-trial-transparency.png), 880 × 376 px, uses the
  same color page, card content, viewport, and 424 × 327 crop at both endpoints.
  Captures wait for CSS transitions to finish. Foreground opacity stays 1.
- [Compact layout before and after](docs/liquefy-ui-trial-narrow-comparison.png),
  820 × 886 px, compares 390 × 844 browser views at scale 1, `latest`, reading
  background, 57%, expanded meanings, open search, and an unknown-word message.
  The revised stage grows vertically; both are full-page captures.

The website documentation's layout is not cloned. The chosen library supplies
material rendering while HuiDict's selected word-card anatomy and Appearance
panel supply the content/layout direction. The generated wallpaper is replaced
by a controllable live reading page; the background alternatives are test
conditions, not substitute assets presented as Apple's wallpaper.

## Required fidelity surfaces

| Surface | Result |
| --- | --- |
| Fonts and typography | macOS system UI font, 27 px bold word, 15 px definitions and pronunciation, 14 px action. Word/header/body/action hierarchy and Chinese content match the selected anatomy. Reader text uses Georgia deliberately as the background. Text remains opaque and wraps within the shrinking card. |
| Spacing and layout | 384 × approximately 288 CSS px default card, 23 px padding, 28 px corners; header divider, pronunciation gap, three meaning rows, and trailing action preserved. The controls and compact expanded state remain visible. The browser panel is wider than the native Settings window to support comparison. |
| Colors and material | 0% settles to opaque white; 100% settles to fully transparent surface fill with a refracting lens and persistent rim/shadow. At 55% the body is more translucent than the selected mock. This is the requested stronger glass trial, not accidental text fading. Dark background uses light foreground and a dark opaque endpoint. |
| Image quality and assets | Live DOM reading content is filtered by the actual library. WebGL canvas rendered at 382 × 286 internal px on the 384 × 288 card and reported no fallback. No screenshot is embedded behind the card. Liquefy icons and Lucide speaker retain vector sharpness. The pink floating browser translation control visible in some evidence is browser chrome, not preview UI. |
| Copy and content | Appearance, Liquid Glass description, transparency percentage, endpoint labels, helper text, and More meanings preserve the approved copy. Three fixed sample entries are available; search errors describe that scope. No preview text claims a live dictionary service. |

## Browser checks

- `npm run build` passed with the pinned published Liquefy UI 1.0.0 packages.
- Keyboard Home/End reached 0%/100%; ArrowRight incremented 0% to 1%.
  A pointer drag moved the displayed value to 57% and changed the rendered material.
- At settled 0% the computed fill was opaque white. At settled 100% it was
  transparent, with `blur(1.5px)` and a live `url(#lq-lens-...)` backdrop filter.
  Card and definition opacity both remained 1. The shader canvas was active.
- Reading, Color, and Dark buttons switched the actual backdrop. Dark at maximum
  was visually inspected. More/Fewer meanings, close/reopen, valid `latest`
  search, and invalid sample search passed through actual UI actions.
- The revised 390 px expanded card remained within the stage with no horizontal
  document overflow. The 1280 px default state also had no horizontal overflow.
- Per-tab simulation of Reduce Motion and Reduce Transparency forced the opaque
  fill, disabled the slider, removed the lens and shader canvas, and displayed
  the preference explanation. Simulation was cleared afterwards; OS settings
  were not changed. Default 68% was restored for handoff.
- Window errors, unhandled rejections, and console errors were recorded through
  the tested interactions and final reload; recorded error arrays were empty.

## Limits and delivery

The full SVG backdrop displacement is Chromium-only in upstream's renderer.
Safari, Firefox, and macOS WKWebView fall back to the CSS material; a WKWebView
embedding would not preserve the demonstrated full effect. No Swift source,
installed native app, certificate, app permissions, or saved app preference was
changed. Native tests and permission redeployment checks are therefore not
applicable to this preview-only change.

Pronunciation is wired to browser speech synthesis, but audible output was not
verified. Physical native selection/image lookup gestures were not part of this
browser trial. The local server serves the production client build at
`http://127.0.0.1:4173/`. No external site was published.
