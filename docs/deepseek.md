# DeepSeek in HuiDict

The HuiDict build uses `deepseek-flash` at `https://api.deepseek.com/chat/completions` for the four
tasks previously handled by Qwen: selecting a contextual dictionary meaning, generating word
translations with grammar labels, translating sentences, and explaining usage in Simplified Chinese.
Thinking is explicitly disabled. The upstream XiaolaiDict build retains its local-model workflow.

When the dictionaries have no entry, the compact and expanded cards offer **Look up online**.
Only clicking that button requests a DeepSeek word translation, using the selected spelling and
the captured sentence when available. Showing or expanding a missing-entry card makes no translation
request. Duplicate clicks share the pending request; closing the card or changing its word, context,
or target language cancels it. A failed answer offers a manual retry, with no automatic retry.
The result is labelled **Online translation · DeepSeek** and carries an AI-suggestion caveat for
names and coined words. It is an API-generated translation, not a live web search or a dictionary
definition, and never creates publisher senses or confirmed study items. Existing translations for
words with dictionary entries retain their current behavior.

HuiDict never opens a model-service connection, prewarms Qwen, downloads weights, or offers a local
model download. Its legacy model-service executable exits immediately if invoked. API errors do not
enable Qwen. Dictionary lookup remains local; the existing Apple and embedding fallbacks remain.
Previously downloaded weights stay on disk and consume no model memory. They are not deleted by an
app update.

## Private credential

Put the key in the repository's ignored `.env` file:

```dotenv
DEEPSEEK_API_KEY=your_key_here
```

Keep that file readable and writable by its owner only (`chmod 600 .env`). Do not commit it. The
installed app reads `~/Library/Application Support/HuiDict/deepseek.env`, a deployment symlink to
the private `.env`. Updating the key takes effect on the next request; no rebuild is needed. The
file is parsed as text and never sourced as shell code. The credential is never in the app bundle,
preferences, diagnostic JSON, error details, or Git history.

To set up the runtime link on another development Mac:

```sh
mkdir -p "$HOME/Library/Application Support/HuiDict"
ln -s "$PWD/.env" "$HOME/Library/Application Support/HuiDict/deepseek.env"
```

## Requests and validation

DeepSeek receives the selected word or sentence, bounded surrounding text, and bounded candidate
meanings or a confirmed meaning hint where needed. It receives no screenshot, reading ledger,
whole dictionary entry, or unrelated files. Explanation requests retain the existing remote-tier
redaction of dictionary prose. Requests go to the fixed official HTTPS endpoint; redirects are
refused. An ephemeral HTTP session stores no cookies or response cache.

Sense answers must be integers in the supplied candidate range, with zero meaning undecided.
Word answers use JSON with one contextual reading or up to three context-free readings. Grammar
labels, duplicate readings, output length, target language, and untranslated echoes are checked
with the existing validators. Truncated, empty, malformed, filtered, or interrupted API answers
are rejected. Request and output limits bound the cost. No automatic retry adds another billable
call. Network access and funded API credit are required.

## Verification

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make local-test
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make local
~/Applications/HuiDict.app/Contents/MacOS/HuiDict --model-status
~/Applications/HuiDict.app/Contents/MacOS/HuiDict --model-report
~/Applications/HuiDict.app/Contents/MacOS/HuiDict --word-translation-report
```

Status is a silent local check of credential presence and local-service absence, not a claim about
API connectivity. The model report makes four small live requests and checks contextual meaning,
word grammar, sentence negation, and explanation language. The word report exercises the existing
thirteen translation and grammar checks through the API. Neither diagnostic can download or
restart Qwen. Signing and macOS permission checks remain required for deployment.

The migration was verified on October 3, 2026 with 2,105 Swift tests and 83 tool tests passing.
The signed build passed all four live provider checks and all thirteen translation-report cases.
Installed build `2026.1003.150800` retained the original signing identity and both macOS grants:
three fresh permission reports passed, and the restarted GUI's own Accessibility and Screen
Capture decisions were Allowed. A rollback bundle was retained beside the installed app. The
selection shortcut and image lookup gestures still need hands-on verification; UI automation
could not reliably trigger them during this deployment.
