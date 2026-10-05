# Liquid Glass lookup cards

Open HuiDict's **Settings → Appearance** to adjust **Transparency**. The preview and open lookup
cards update immediately, and the preference is saved across restarts. The default is 55%.

Moving left adds a neutral opaque wash; moving right reveals more of the background. Native
Liquid Glass supplies the curved optical edge and refraction. The percentage controls the wash,
not the opacity of the text or the entire window. Text, icons, and actions do not fade with the slider.
“More meanings” uses the system accent color and opens the existing detailed card.

The preview uses the actual compact card renderer over sample reading text. It preserves the
existing grouping of meanings and the five-meaning limit. The sample's buttons are noninteractive;
the same controls on a real lookup retain their existing actions.

When macOS **Reduce Transparency** is enabled, the card uses an opaque background and the slider
is disabled. The saved value is retained for when that accessibility setting is turned off.
Increased Contrast strengthens the card edge.

## Validation

Run `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make local`. Swift tests cover
persistence, invalid preferences, continuous surface values, and the accessibility fallback.

The installed app's `--settings-report` measures every pane. To capture its own Appearance pane
at 0%, the saved value, and 100%, plus its Permissions pane, opt in to evidence:

```sh
HUIDICT_SETTINGS_EVIDENCE_DIRECTORY="$PWD/.build/liquid-glass-evidence" \
  ~/Applications/HuiDict.app/Contents/MacOS/HuiDict --settings-report
```

The diagnostic checks the existing Screen Recording grant silently before capture. It never
requests permission, captures only its own settings window, reports capture failures, and restores
the saved transparency after collecting evidence. This optional mode requests activation of its
settings window. Normal diagnostics do not capture or activate it.

See [the selected design](liquid-glass-design.png) and [design QA](../design-qa.md). Selection and
image lookup gestures, slider dragging, and keyboard adjustment should also be tried in the
installed app; programmatic state changes and headless lookups do not substitute for those checks.
