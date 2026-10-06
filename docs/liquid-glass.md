# Liquid Glass lookup cards

Open HuiDict's **Settings → Appearance** to adjust **Transparency**. The preview and open lookup
cards update immediately, and the preference is saved across restarts. The default is 55%.

Moving left makes the surface opaque; moving right reveals more of the background. The card uses
the actual `@liquefy-ui/react` and `@liquefy-ui/core` 1.0.0 packages inside an offline WKWebView.
Liquefy's lens map refracts a live ScreenCaptureKit backdrop through a WebGL 2 adapter; the library
supplies the rim, edge, veil, and reflections. This adapts Liquefy to WebKit rather than using
Apple's proprietary Liquid Glass renderer. See [the renderer source and rebuild steps](../Previews/LiquefyGlass/README.md).

At 0% the surface is opaque; 100% is the clearest glass setting, with softened background detail
and an illuminated rim. Text, icons, and actions remain native and do not fade with the slider.
Mostly clear cards adapt their foreground colors to light and dark captured backgrounds.
“More meanings” uses the system accent color and opens the existing detailed card.

The lookup keeps its material visually active even though the floating window remains unfocused.
The transparent window backing lets the actual card show the background and respond to
transparency changes. Clicking a card can still activate HuiDict, as it did before this integration;
the existing focus limitation is recorded in [native QA](../design-qa.md).

Backdrop frames remain in memory, exclude the lookup window itself, refresh at up to six frames
per second, and never leave the app. Capture stops when the card closes. The existing silent
permission probe gates capture. Native material remains available until the renderer and backdrop
are ready, or when capture is unavailable.

The preview uses the actual compact card renderer over sample reading text. It preserves the
existing grouping of meanings and the five-meaning limit. The sample's buttons are noninteractive;
the same controls on a real lookup retain their existing actions. Its backdrop is rendered from
the sample page in memory and does not capture the desktop.

When macOS **Reduce Transparency** is enabled, the card uses an opaque background and the slider
is disabled. The saved value is retained for when that accessibility setting is turned off.
Increased Contrast strengthens the card edge. Reduce Motion suppresses the animated rim.

## Validation

Run `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make local`. Swift tests cover
persistence, invalid preferences, continuous surface values, and the accessibility fallback.

The installed app's `--settings-report` measures every pane. To capture its own Appearance pane
at 0%, the saved value, and 100%, plus its Permissions pane, opt in to evidence:

```sh
HUIDICT_SETTINGS_EVIDENCE_DIRECTORY="$PWD/.build/liquefy-native-settings-qa" \
  ~/Applications/HuiDict.app/Contents/MacOS/HuiDict --settings-report
```

The diagnostic checks the existing Screen Recording grant silently before capture. It never
requests permission, captures only its own settings window, reports capture failures, and restores
the saved transparency after collecting evidence. This optional mode requests activation of its
settings window. Normal diagnostics do not capture or activate it.

To verify the **actual floating lookup**, rather than just the Settings preview:

```sh
HUIDICT_LOOKUP_GLASS_EVIDENCE_DIRECTORY="$PWD/.build/liquefy-native-qa" \
  ~/Applications/HuiDict.app/Contents/MacOS/HuiDict --panel-report
```

This opt-in report leaves one real lookup window open while changing the same observable preference
as the slider to 0%, 25%, 55%, 75%, the saved value, and 100%. It captures only HuiDict's card and
its own white, colored, and dark reading pages. Each page is also captured without the card as a
reference. The report compares the card's interior with that reference using correlation, so a tint
or luminance shift alone cannot establish transparency. All three pages require visible background
detail at 100% and a substantial gain over 0%. It also records focus state and restores
the saved preference. It posts no input events and records no fabricated reading history.

See [the native transparency comparison](liquefy-native-transparency.png),
[the dark-background card](liquefy-native-dark.png), and
[the installed Appearance pane](liquefy-native-appearance.png).

See [the selected design](liquid-glass-design.png) and [design QA](../design-qa.md). Selection and
image lookup gestures, slider dragging, and keyboard adjustment should also be tried in the
installed app; programmatic state changes and headless lookups do not substitute for those checks.
