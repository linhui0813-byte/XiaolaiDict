# Liquid Glass lookup cards

Open HuiDict's **Settings → Appearance** to adjust **Transparency**. The preview and open lookup
cards update immediately, and the preference is saved across restarts. The default is 55%.

Moving left adds a neutral opaque wash; moving right reveals more of the background. The slider
adjusts both the native glass background contribution and the neutral wash. Adjusting the wash
alone left small reading text hidden by the native blur, even at 100%. Native Liquid Glass still
supplies blur and refraction, with an illuminated rim around the card. At 0% the surface is opaque;
100% is the clearest glass setting, retaining some material and contrast for reading. Text, icons,
and actions do not fade with the slider; small local shadows help separate them from the backdrop.
“More meanings” uses the system accent color and opens the existing detailed card.

The lookup keeps its material visually active even though the floating window remains unfocused.
It clears the SwiftUI window backing explicitly. This lets the actual card show the background
and respond to transparency changes while the reader continues typing in the other app.

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

To verify the **actual floating lookup**, rather than just the Settings preview:

```sh
HUIDICT_LOOKUP_GLASS_EVIDENCE_DIRECTORY="$PWD/.build/liquid-glass-popup-evidence" \
  ~/Applications/HuiDict.app/Contents/MacOS/HuiDict --panel-report
```

This opt-in report leaves one real lookup window open while changing the same observable preference
as the slider to 0%, 25%, 55%, 75%, the saved value, and 100%. It captures only HuiDict's card and
its own white, colored, and dark reading pages. Each page is also captured without the card as a
reference. The report compares the card's interior with that reference using correlation, so a tint
or luminance shift alone cannot establish transparency. The white-page check requires visible
background detail at 100% and a substantial gain over 0%. It also records focus state and restores
the saved preference. It posts no input events and records no fabricated reading history.

See [the actual pop-up](liquid-glass-popup.png), [its transparency levels](liquid-glass-popup-transparency.png),
and [the dark-background check](liquid-glass-popup-dark.png).
The [reported and corrected endpoints](liquid-glass-transmission-comparison.png) and
[focused background-detail comparison](liquid-glass-transmission-detail.png) document the fix.

See [the selected design](liquid-glass-design.png) and [design QA](../design-qa.md). Selection and
image lookup gestures, slider dragging, and keyboard adjustment should also be tried in the
installed app; programmatic state changes and headless lookups do not substitute for those checks.
