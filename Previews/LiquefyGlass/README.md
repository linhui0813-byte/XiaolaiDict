# HuiDict Liquefy UI trial

A browser preview of HuiDict's dictionary card using the actual published
[`@liquefy-ui/react`](https://github.com/liquefy-ui/liquefy-ui) 1.0.0 package,
its `LiquidGlass` surface, and `LiquidSlider`. The local preview is served from
the built client files. It does not replace HuiDict's installed native pop-up.

The card preserves the selected design's word header, pronunciation, Chinese
meaning rows, close/search actions, and More meanings link. Search accepts three
sample entries: `refused`, `latest`, and `appearance`. Pronunciation uses the
browser's speech synthesis. No dictionary service, credentials, capture API,
or native permission settings are accessed by this preview.

## Run

Requires Node 20.19 or newer.

```sh
cd Previews/LiquefyGlass
npm ci --ignore-scripts --no-audit --no-fund
npm run build
npm run preview -- --host 127.0.0.1 --port 4173 --strictPort
```

Open the local URL printed by the server in Chrome or another Chromium browser.
`npm run dev -- --host 127.0.0.1 --port 4173 --strictPort` is available for editing.

## Material controls

- Transparency maps 0–100 to Liquefy's surface `veil` of 1–0. The maximum surface
  fill is overridden to opaque white (or dark navy on the dark backdrop) so 0%
  is genuinely opaque. Foreground text and controls retain opacity 1.
- Frost decreases from 6.5 px to 1.5 px with transparency. The actual library lens
  refracts the live reading page with a 24 px bezel, curve 2, and refraction 1.
  Background paragraphs are real DOM text, not an embedded screenshot.
- Shader highlights keep a minimum strength at the clear endpoint. A faint rim
  and shadow remain so the clear card still reads as a glass surface.
- `interactive={false}` holds the card still. The provider's motion remains on
  because Liquefy's current shader controller also requires that setting.
  Reduce Motion disables motion and WebGL; Reduce Transparency forces the opaque
  endpoint and disables the slider. These preferences are observed dynamically.
- Background choices test a plain reading page, a blue/lilac environment, and
  a dark reading page. At maximum transparency, background words are intentionally
  more visible; lower values give a quieter surface for reading definitions.

## Native compatibility

Liquefy UI is a React/web renderer, not a SwiftUI package. Its real backdrop
refraction uses an SVG displacement filter in `backdrop-filter`, which the
[upstream source](https://github.com/liquefy-ui/liquefy-ui/blob/96af8d8f9757420f60c6d085aa0b49bdaa8a0ad6/packages/core/src/lens-filter.ts)
limits to Chromium. Safari, Firefox, and macOS `WKWebView` use the CSS material
fallback. A native renderer or a separate Chromium runtime would be needed to
carry the full optical effect into HuiDict's floating panel; embedding this
preview in `WKWebView` would not preserve the effect demonstrated here.

This branch therefore makes the chosen library concrete and reviewable before
changing the app's window/rendering architecture. Existing native Swift sources,
installed signing identity, permissions, and saved transparency preference are
untouched by this trial. The previous native transparency implementation remains
in the parent commit `73051f7`.

## References and validation

- Selected library source inspected at commit
  `96af8d8f9757420f60c6d085aa0b49bdaa8a0ad6`; runtime packages are pinned in
  `package.json` and resolved in `package-lock.json`.
- [Live glass documentation](https://liquefy-ui.com/#/components/glass).
- Liquefy UI and its icons: MIT. Speaker icon: Lucide (ISC).
- [Design QA and browser validation](../../design-qa.md).

The bundled static worker scaffold is retained for optional future hosting. No
external hosting service is configured or deployed by this trial.
