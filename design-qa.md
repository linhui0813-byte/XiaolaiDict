# Compact lookup design QA

Final result: blocked pending interactive verification and a production build.

The visual comparison passes. The target is Hui's supplied `refused` lookup screenshot. The
implementation is the actual native SwiftUI card rendered with synthetic bilingual fixture data.
The reference and implementation were placed together in a normalized comparison image before
review. No actionable P0, P1, or P2 visual issues were found in this comparison.

![Compact native lookup with fixture data](docs/compact-lookup.png)

The card surface is 300 points wide at the standard text size, matching the reference. Its outer
frame, including the transparent shadow margin, is 321 × 250 points. The word is prominent,
pronunciation sits below a divider, definitions are short, and `More meanings` is at the lower
right. Simplified Chinese localization displays `更多释义`. The neutral surface and shadow work
in light and dark appearances. A larger text setting produces a 401 × 295 point outer frame.

The reference's favorite star is omitted for the requested lookup-focused flow. Pronunciation
comes from the dictionary; the card does not invent separate regional readings. Dictionary form
and near-match cues remain available. Uncertain meanings retain a short visible caveat.

![Expanded native lookup with fixture data](docs/expanded-lookup.png)

Expansion reveals every meaning, the captured context, publisher sense text including examples,
dictionary switching, and the existing study actions. Long details scroll within the existing
height cap. The expanded fixture has a 417 × 405 point outer frame. The same panel can collapse
again, and a new request starts compact.

## Validation

- 109 focused Swift tests passed, including compact summary behavior, uncertainty preservation,
  definition deduplication, native layout, larger text, height limits, existing selection behavior,
  control wiring, source string coverage, and design token checks.
- Native renders were inspected in compact, expanded, large-text, and dark states.
- Swift syntax parsing and `git diff --check` passed.

These are view-only checks, not a production build. They used an isolated temporary package with
the installed macOS 26.5 SDK. Three environment macros were expanded into equivalent environment
keys; Xcode canvas previews and on-device generation were omitted. The SDK's model error naming
was adapted in the harness. Production source, signing, and model behavior were not changed for
this workaround. The app target also compiled in that harness.

Three catalog infrastructure tests were excluded: two depend on the full package's source layout,
and the catalog compilation test requires the unavailable `xcstringstool`.

## Remaining verification

- Automatic approval review rejected opening the locally built preview for interactive testing
  because it is an unrecognized app requiring action-time approval. More meanings, collapse,
  new-request reset, and close have not yet been tested through the live UI.
- A production macOS 27 build is blocked by missing Foundation Models and SwiftUI compiler
  plugins. The selected Command Line Tools also lack the Metal compiler and catalog compiler.
- No valid code-signing identity is available. The installed signed app has not been replaced;
  deploying this branch as a working app remains blocked.
