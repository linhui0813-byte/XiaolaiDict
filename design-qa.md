# Liquefy UI refinement design QA

final result: passed

This result covers the refined browser preview on `feature/liquefy-ui-trial`.
Native integration remains pending. The result does not claim exact reproduction
of Apple's Liquid Glass. The [native transparency QA](design-qa-native-transparency.md)
is historical evidence for the unchanged native app. The original browser trial
report is retained in commit `8c6c7f6`.

## Findings and fixes

- **Resolved P1 — transmitted background words competed with definitions.**
  Frost now ranges from 10.5 to 4.5 px instead of 6.5 to 1.5 px. Background details
  remain visible but become softer bands. Definitions increase from 15 to 16 px,
  and the word increases from 27 to 29 px. Foreground opacity remains 1.
- **Resolved P2 — the blue surface looked flat beside the selected design.**
  The reading page's white fill increases from 0.5 to 0.84, reducing the blue cast.
  Surface veil now follows `(1 - transparency / 100) ** 1.45`, giving the middle
  settings a clearer body. The wider refracting bezel, stronger shader rim,
  inset reflections, and soft shadow make the boundary more distinct.
- **Resolved P2 — keyboard focus disappeared when search closed.** Search now
  returns focus to its button after a lookup or Escape. A second Escape closes
  the card. Normal speech cancellation no longer displays an error.
- **Resolved P2 — the reading sentence did not fit every sample word.**
  `latest` and `appearance` now have their own grammatical reading contexts.

No actionable P0/P1/P2 issue remains in the tested preview states. At maximum
transparency the reading page remains visible by design; lower values provide
stronger separation. The existing compact layout remains intact.

## Source and rendered evidence

- Layout source: [selected Appearance design](docs/liquid-glass-design.png),
  1487 × 1058 px, `refused`, 55%. The source is a generated design reference;
  its original display density is unknown.
- Implementation: [refined browser preview](docs/liquefy-ui-trial-preview.png),
  1280 × 900 px. CSS viewport 1280 × 900, device scale 1, 1 PNG px per CSS px.
  Default state: `refused`, Color background, 68%, closed search/details.
- [Matched before/after](docs/liquefy-ui-refinement-comparison.png),
  1320 × 506 px, compares the previous and refined implementations at 68%.
  Both 1280 × 900 browser canvases are scaled proportionally to 640 px wide.
- [Source and both implementations](docs/liquefy-ui-refinement-source-comparison.png),
  1680 × 440 px, compares the selected design, previous trial, and refinement at
  55%. Each canvas is scaled proportionally into a 540 px wide slot.
- [Focused material comparison](docs/liquefy-ui-refinement-material-comparison.png),
  1260 × 370 px, contains the same three 55% states at 400 px wide. Crops are
  source `(677,309)-(1221,689)`, previous `(537,208)-(945,528)`, and refined
  `(531,205)-(951,532)`. This is an art-direction comparison, not a pixel clone.
- [Opaque and clear endpoints](docs/liquefy-ui-trial-transparency.png),
  880 × 383 px, compares 0% and 100% with identical content, Color background,
  viewport, and `(531,205)-(951,532)` crop. Finite CSS transitions settle before
  capture; the card remains 400 × 306.34 CSS px at both endpoints.
- [Compact expanded state](docs/liquefy-ui-refinement-narrow.png), 390 × 844 px,
  uses `latest`, Reading background, 57%, expanded meanings, open search,
  and an unknown-word message. The card and controls fit within the stage.

The previous implementation captures are retained in the ignored
`.build/liquefy-qa` directory; refinement captures are in
`.build/liquefy-refinement`. Combined evidence is committed above. The browser's
pink translation control visible in some full captures is not preview UI.

## Required fidelity surfaces

| Surface | Result |
| --- | --- |
| Fonts and typography | macOS system UI font; 29 px bold word, 16 px definitions, 15 px pronunciation, 14 px More meanings. The selected header/body/action hierarchy and Chinese definitions are preserved. Compact mode uses 25 px word and 14 px definitions. Reader text deliberately uses Georgia. |
| Spacing and layout | Default card is 400 × 306.34 CSS px with 24 px padding and 30 px corners. Divider, pronunciation gap, three meaning rows, and trailing action preserve the source anatomy. Circular header controls are 30 px. The browser Appearance panel is wider than the source/native Settings panel. |
| Colors and material | Default 68% settles to white surface alpha 0.191632 and 6.42 px blur. The actual Liquefy lens refracts live content with a 30 px bezel, curve 2.4, refraction 0.92. At 0% the fill is opaque white; at 100% it is transparent with 4.5 px blur and a persistent illuminated rim. Dark background uses light text and a navy opaque endpoint. |
| Image quality and assets | Actual published Liquefy UI 1.0.0 supplies the optical rendering. Its shader canvas is 398 × 304 internal px on the default card. Background paragraphs are live DOM text. Liquefy search/close icons and the Lucide speaker remain vector assets. No screenshot is embedded behind the card. |
| Copy and content | Appearance, material description, transparency value, endpoint captions, and helper text preserve the selected copy. Search accepts the three documented preview words, and unknown words receive a clear scope explanation. More/Fewer meanings work. Sample reading sentences now follow the selected word. |

The generated wallpaper is represented by controllable Reading, Color, and Dark
backgrounds. This is deliberate test content. The website documentation's layout
is not being cloned; its package supplies rendering for HuiDict's selected card.

## Browser validation

- `npm run build` passed after the final source change, with packages pinned by
  `package-lock.json`. The running local server serves `dist/client`.
- Keyboard Home/End reached 0%/100%; ArrowRight incremented 0% to 1%.
  A real pointer drag reached 55% and changed the rendered material.
- Settled 0% computed fill: `color(srgb 1 1 1)`, blur 10.5 px, no lens URL.
  Settled 100% fill: `color(srgb 0 0 0 / 0)`, blur 4.5 px, live lens URL.
  Card and definition opacity both stayed 1. The shader canvas remained active,
  with element opacity 0.85 at the clear endpoint.
- Reading, Color, and Dark buttons changed the actual background. Dark at 100%
  was captured and visually inspected. Both valid sample searches, invalid
  search, More/Fewer meanings, close/reopen, and two-stage Escape passed.
  Search returned focus to its button after a lookup and after Escape.
- At 390 px, the document width was 390 px. The expanded card was 306 × 421.98
  CSS px within a 338 × 453.98 stage, with no clipped content or controls.
  The 1280 px default state also had no horizontal overflow.
- Per-tab simulation of Reduce Motion and Reduce Transparency forced 0%, disabled
  the slider, removed the lens and shader canvas, and displayed the preference
  explanation. Simulation was cleared; system settings were not changed.
- Window errors, unhandled rejections, and console errors recorded after loading
  the final build and throughout these interactions were empty. Final script
  asset: `index-Dqu61md1.js`; final CSS asset: `index-f-dWI4MJ.css`.
- The finished preview was restored to `refused`, Color background, 68%, closed
  search/details, at the 1280 × 900 viewport for handoff.

## Limits and delivery

Upstream's full SVG backdrop displacement is Chromium-only. Safari, Firefox,
and macOS WKWebView use the CSS fallback; a WKWebView embedding would not preserve
this full optical effect. A native renderer or separate Chromium runtime is
still needed for integration into HuiDict's floating panel.

This refinement changes only the browser preview and its evidence/documentation.
Native signing, installation, permissions, and saved app preferences were not
changed, so Swift tests and native permission deployment checks do not apply.
Pronunciation uses browser speech synthesis; audible output was not verified.
Native selection/image lookup gestures were outside this preview check.

The production client build is served locally at `http://127.0.0.1:4173/`.
No external site was published.
