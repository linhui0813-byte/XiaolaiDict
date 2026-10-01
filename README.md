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
labelled separately from the dictionary's meanings, with `n.`, `v.`, `adj.`, or another grammar
label beside each generated reading. Context determines the label; a passive verb remains `v.`.
**More meanings** opens the dictionary details.
Sentence translations and usage explanations in the HuiDict build also target Simplified Chinese.
See [translation verification](docs/translation-upgrade.md) for the checked examples and a native card render.
See [generated grammar labels](docs/word-translation-grammar.md) for the word-reading format and its checks.

Install Xcode 27 and its Metal toolchain, then run:

```sh
python3 Tools/local-signing.py setup
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make local
```

The output is `.build/HuiDict.app`, with identifier `com.linhui.huidict`. The setup command creates
a persistent certificate in a dedicated local keychain so updates keep a compatible app identity.
It changes neither system certificate trust nor the login-keychain search list and needs no paid
Developer ID. Signing credentials stay outside the repository in HuiDict's Application Support folder.
The build stops if this identity is missing; it cannot fall back to ad-hoc signing. Before publishing
an update it checks that the certificate and designated requirement match the installed app and
the previous build. If the Signing folder is lost, recover it instead of generating a new identity.
Each service accepts only the exact signed host app; the app also verifies the bundled services.
Unsigned or modified bundles are refused.
The normal Developer ID release command remains available separately.

Copy HuiDict to your Applications folder and grant it Accessibility and Screen Recording when
prompted. These are separate from the upstream app's permissions. Switching from an ad-hoc build
to the persistent signer requires replacing the old permission entries once. Later builds reuse
the certificate. Keep the Signing folder when updating the app; replacing or losing that identity
requires granting permissions again. This local build is not notarized for public distribution.
Its history and model files live in `~/Library/Application Support/HuiDict`.

Before replacing an installed app, run the same compatibility check explicitly:

```sh
python3 Tools/local-signing.py check-update .build/HuiDict.app
```

After installation, verify effective permission grants without requesting access:

```sh
~/Applications/HuiDict.app/Contents/MacOS/HuiDict --permission-report
```

This returns JSON and exit status zero only when both permissions are granted to the current
process. It keeps unknown capture failures separate from denied access and never calls a
permission-request API or opens an app window. A terminal can lend its permissions to a child
process: validate saved HuiDict grants through a normal app launch and macOS TCC decisions
attributed to HuiDict itself, rather than relying on a passing terminal report alone.

The local build runs the Swift tests first. Tests requiring optional licensed sideloaded dictionaries
are reported as skipped when those fixtures are not installed; the installed Apple dictionary tests run.

To check word translations, grammatical readings, negation, and contextual explanations through
the bundled Qwen service using an existing model (no download), run:

```sh
.build/HuiDict.app/Contents/MacOS/HuiDict --word-translation-report
```

If Qwen is unavailable or returns an invalid word gloss, the compact card keeps its dictionary
meanings. Generated glosses do not become dictionary senses or saved sense confirmations.
