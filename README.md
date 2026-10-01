# XiaolaiDict

A menu-bar dictionary for macOS that marks **which sense** of a word you just read.

## Requirements

- macOS 27 or later
- Apple Silicon

## Install

```sh
brew tap xiaolai/tap
brew install --cask xiaolaidict
```

To update later: `brew upgrade --cask xiaolaidict`

Or download the `.dmg` from [Releases](https://github.com/xiaolai/XiaolaiDict/releases) and drag the
app to Applications. It is signed and notarised, so Gatekeeper opens it without a right-click.

**Installing the upstream release needs neither Xcode nor a developer certificate.** The default
release build uses Developer ID signing and requires the app and its services to share a signing team.

## Build HuiDict locally

This fork includes the compact lookup card and an independent local app called **HuiDict**.
With a local Qwen model installed, the card automatically shows a short Chinese translation of
the selected word, using its surrounding sentence when available. A word-form note explains
forms such as **refused** (past tense / past participle of **refuse**). Qwen's generated gloss is
labelled separately from the dictionary's meanings; **More meanings** opens the dictionary details.
Sentence translations and usage explanations in the HuiDict build also target Simplified Chinese.
See [translation verification](docs/translation-upgrade.md) for the checked examples and a native card render.

Install Xcode 27 and its Metal toolchain, then run:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make local
```

The output is `.build/HuiDict.app`, with identifier `com.linhui.huidict`. It uses an ad-hoc code
signature for this Mac and needs no paid Developer ID. Each service accepts only the exact signed
host app; the app also verifies the bundled services. Unsigned or modified bundles are refused.
The normal Developer ID release command remains available separately.

Copy HuiDict to your Applications folder and grant it Accessibility and Screen Recording when
prompted. These are separate from the upstream app's permissions. A new local build can require
granting them again because its code signature changes. This local build is not notarized for
public distribution. Its history and model files live in `~/Library/Application Support/HuiDict`.

The local build runs the Swift tests first. Tests requiring optional licensed sideloaded dictionaries
are reported as skipped when those fixtures are not installed; the installed Apple dictionary tests run.

To check word translations, grammatical readings, negation, and contextual explanations through
the bundled Qwen service using an existing model (no download), run:

```sh
.build/HuiDict.app/Contents/MacOS/HuiDict --word-translation-report
```

If Qwen is unavailable or returns an invalid word gloss, the compact card keeps its dictionary
meanings. Generated glosses do not become dictionary senses or saved sense confirmations.
