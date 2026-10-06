# HuiDict Liquefy glass

A browser preview and native HuiDict integration using the actual published
[`@liquefy-ui/react`](https://github.com/liquefy-ui/liquefy-ui) 1.0.0 package,
its `LiquidGlass` surface, and `LiquidSlider`. The local preview is served from
the built client files. The native app embeds a separate offline background
surface under its existing SwiftUI lookup content.

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

- Transparency maps 0–100 to Liquefy's surface `veil` of 1–0 using
  `(1 - transparency / 100) ** 1.45`. This gives the middle of the range a clearer
  body while retaining a genuinely opaque white endpoint (dark navy on the dark
  backdrop). Foreground text and controls retain opacity 1.
- Frost decreases from 10.5 px to 4.5 px with transparency. The actual library lens
  refracts the live reading page with a 30 px bezel, curve 2.4, and refraction 0.92.
  Background paragraphs are real DOM text, not an embedded screenshot.
- Shader highlights keep a minimum strength of 0.85 at the clear endpoint. A
  brighter rim, inset reflections, and a soft shadow keep the boundary visible.
  The reading page has less blue tint, and the stronger blur softens background
  words so they compete less with the larger 16 px definitions.
- `interactive={false}` disables pointer-driven tilt. The provider's motion remains on
  because Liquefy's current shader controller also requires that setting.
  Reduce Motion disables motion and WebGL; Reduce Transparency forces the opaque
  endpoint and disables the slider. These preferences are observed dynamically.
- Background choices test a plain reading page, a blue/lilac environment, and
  a dark reading page. At maximum transparency, background words are intentionally
  more visible; lower values give a quieter surface for reading definitions.
- Search returns keyboard focus to its button after a lookup or Escape. A second
  Escape closes the card. Sample reading sentences follow the selected word.

## Native integration

Liquefy UI is a React/web renderer, not a SwiftUI package. Its real backdrop
refraction uses an SVG displacement filter in `backdrop-filter`, which the
[upstream source](https://github.com/liquefy-ui/liquefy-ui/blob/96af8d8f9757420f60c6d085aa0b49bdaa8a0ad6/packages/core/src/lens-filter.ts)
limits to Chromium. Simply embedding the browser preview in `WKWebView` would
lose that displacement. The native adapter instead imports the upstream core's
`createLensMap` and samples the backdrop with that map in WebGL 2. The real
`LiquidGlass` component supplies the rim shader, edge, veil, and reflections.
This is an adaptation of Liquefy's optics, not Apple's proprietary renderer.

`LiquefyGlassSurface.swift` hosts the offline renderer as a background-only view.
Text, pronunciation, Close, Dictionary, More meanings, and the non-key lookup
window remain native. `LiquefyBackdropStream.swift` supplies the rectangle behind
the visible card through ScreenCaptureKit, excluding the lookup window itself.
Frames remain in memory, are sampled at up to six frames per second, and never
leave the app. Capture stops when the card closes. The existing silent permission
probe gates capture; this integration does not request additional permission.
The native material remains available when capture or WebGL is unavailable.

The Appearance pane renders its own sample page into memory and uses the same
renderer and persisted transparency preference. It does not capture the desktop.
Reduce Transparency uses the opaque native surface; Reduce Motion disables the
animated rim. Foreground colors adapt to dark and light captured backgrounds once
the surface is mostly clear.

The native backdrop uses mipmap filtering for a smooth blur, and foreground
contrast follows an averaged 16 by 16 brightness sample. The complete surface
is clipped to the native rounded card. [Native transparency screenshots](../../docs/liquefy-native-transparency.png)
and the [installed Appearance pane](../../docs/liquefy-native-appearance.png)
show the result. The optical diagnostic checks 18 readings across three native
reading pages and restores the saved transparency afterward.

Rebuild the embedded surface after changing `native/`, its build script, or the
package lock:

```sh
cd Previews/LiquefyGlass
npm ci --ignore-scripts --no-audit --no-fund
npm run build:native
cd ../..
python3 Tools/verify-liquefy.py Resources/LiquefyGlass
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make local
```

The generated HTML includes its CSS and JavaScript. It needs no development
server or network connection. Its content policy forbids network access, and
the host permits only its local surface file to load. The generated manifest
records source and payload hashes plus exact bundled package versions. The
native build rejects stale assets and includes every rendered package's license.
Local updates retain HuiDict's existing certificate, bundle identifier, and
installed path.

## References and validation

- Selected library source inspected at commit
  `96af8d8f9757420f60c6d085aa0b49bdaa8a0ad6`; runtime packages are pinned in
  `package.json` and resolved in `package-lock.json`.
- [Live glass documentation](https://liquefy-ui.com/#/components/glass).
- Liquefy UI and its icons: MIT. Speaker icon: Lucide (ISC).
- [Native design QA](../../design-qa.md).
- [Browser preview validation](../../design-qa-liquefy-preview.md).

The bundled static worker scaffold is retained for optional future hosting. No
external hosting service is configured or deployed by this preview.
