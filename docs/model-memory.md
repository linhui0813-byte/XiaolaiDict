# HuiDict local-model memory

Measurements on Hui's 24 GiB Mac running macOS 27.0.1, October 1, 2026. All sizes below are MiB
(1,048,576 bytes). Disk size, GPU allocations, current process footprint, and process peak are
reported separately. The benchmark uses the same local-only loader, prompts, guided generation,
and translation validation as the signed model service. It does not request capture permissions.

## Experiment results

| Variant | Fresh runs | Process peak MiB | End footprint MiB | Warm word median / p95 ms |
| --- | ---: | --- | --- | --- |
| Existing 4B 4-bit, 256 MiB pool, serial | 5 | 3709.3–3729.1 | 2575.6–2596.5 | 886.9 / 983.5 |
| Existing 4B 4-bit, 256 MiB pool, overlapping requests | 2 | 3724.9–3732.8 | 2588.6–2755.2 | 871.4 / 1014.7 |
| Existing 4B 4-bit, 64 MiB pool, overlapping requests | 3 | 3577.2–3596.4 | 2546.5–2568.4 | 895.8 / 1304.5 |
| Candidate 4B 3-bit, 256 MiB pool, overlapping requests | 3 | 3268.3–3272.0 | 2215.8–2222.3 | 697.5 / 857.8 |
| Candidate 2B 4-bit, 256 MiB pool, overlapping requests | 3 | 2343.6–2365.2 | 1277.7–1370.0 | 382.4 / 444.7 |

The 64 MiB pool reduced load peak by about 130 MiB but its measured warm p95 rose about 29% against
the matched overlapping baseline. The median rose about 3%. These small samples do not prove a
tail-latency distribution or identify allocation churn as the cause. Retain the 256 MiB default;
the bounded override exists for future measurements, without changing weights or admission.

The 3-bit candidate reduced GPU active allocations from 2259.9 to 1758.7 MiB and process peak by
about 460 MiB. Its end footprint fell less: buffer reuse and process accounting still matter.
It was rejected for repeatable new critical failures, regardless of memory or speed savings.

The 2B fallback saved more than 1 GiB of resident footprint and roughly halved word latency, but
also failed critical screening. It is not a suitable drop-in replacement for the existing prompts
and structured generation on this runtime. Neither candidate was copied into the production model
store or made selectable; the working 4-bit weights remain intact.

## Idle release

The installed signed 4-bit app was measured with a temporary 120-second idle override, then the
previous setting was restored. It selected the pinned installed model without downloading,
prewarmed in 1.65 seconds, and correctly answered the ship's-hold sense, translation, and explanation.
Its footprint was 2584 MiB. After the last request it exited in 120.4 seconds; a fresh status request
started an unloaded service with a 37 MiB footprint. The default idle interval is now 120 seconds
instead of 600. Existing explicit overrides remain respected and clamped. Draining and cancellation
are unchanged. A lookup after unloading pays a cold load again; baseline prewarm times were
1.73–4.94 seconds, including the first run's cold system caches.

Keep the menu-bar app closed during the standalone signed `--model-report` diagnostic. Separate app
clients can own separate XPC service instances; the process-exit watch cannot identify a clean
unload while another instance of the same executable remains running. This is a measurement
constraint, not evidence that a 120-second idle timer failed.

## Quality adjudication

The 52 authored screening cases include the existing 13 checks and additional word senses,
parts of speech, active/passive/adjective forms, idioms, numbered sense choices, sentence negation,
and conflicting hints. Four representative requests also run together on the same model service.
These checks are screening, not a broad translation-equivalence guarantee. Semantic review is
separate from a synonym/string match.

The existing 4-bit baseline already mislabels direction “left” as a verb. It intermittently labels
passive “closed” and “broken” as adjectives. Those remain translation issues; this update does not
change prompts or hide them by relaxing checks.

The 3-bit candidate consistently adds a noun reading to isolated “refused” and “reopened”, produces
an empty “approach” gloss under the conflicting hint, and picks sense 11 from three-item lists.
It also returns untranslated/invalid gloss failures and mislabels additional words. These are new
critical regressions, not harmless alternative Chinese wording. Some automatic negation failures
are false positives: “未被驳回” preserves the meaning but the fixture expects “拒”. The false positives
do not explain or excuse the other failures. No production model replacement is justified.

The 2B fallback repeatedly calls active “refused” and “reopened” adjectives, mistakes tree “bark”
for “rough”, and translates “table the discussion until next month” as proposing the discussion
rather than postponing it. Those are new grammar/meaning regressions. Some “object” failures only
reflect wording outside the fixture or translating more than the selected word; they do not rescue
the critical failures. The three runs failed 19–22 screening rows including concurrent requests.
These results reject these specific pinned artifacts with the current runtime and prompts; they
are not a claim about every 3-bit or 2B model.

## Candidate identity and provenance

Both candidates are excluded from `ModelManifest.all`, the setup board, and automatic selection.
They require an explicit experiment store in the benchmark. Production retains its existing pinned
4B model and downloader. No ModelScope mirror was verified for either candidate.

The [3-bit community artifact](https://huggingface.co/mlx-community/Qwen3.5-4B-3bit) is pinned to
`6a87bc4e52f513d6d68397b844db31a255f3fb19`. Its 2,508,701,687-byte safetensors file has SHA-256
`2d45a057491949fc8f03d924023233beace74eba77da8a9f7bd7112136762d39`. Small files were checked against
the publisher's Git blob or LFS digests, and the complete weights were SHA-256 verified before load.
The tokenizer matches the existing model. Configuration differences are the two quantization bit
fields, 4 to 3; both use affine groups of 64. The language tensors occupy 1,841,520,128 bytes and the
vision tensors 667,028,480 bytes. The loader already excludes vision weights; removing them from a
download would not establish another RAM saving. The conversion's higher-precision source is not
established by a model card; hashes prove byte identity, not conversion provenance or quality.

The [2B 4-bit community artifact](https://huggingface.co/mlx-community/Qwen3.5-2B-4bit) is separately
pinned to `674aaa7240b91e8012fcad5d791b7dfe5ba90207`; its model card names Qwen/Qwen3.5-2B and
mlx-vlm 0.3.12 as the conversion source/tool. Its 1,722,271,785-byte safetensors file has SHA-256
`713fe7e5d3c3965f7106b0d0ee17615f7869c23c8d327996df8c1196fbcf07d5`. This screening candidate uses
the existing 4B admission bound conservatively. Neither model download executes repository code.
The experiment store retains the pinned Apache 2.0 license text. The 2B full weight hash was also
verified before load; its language tensors occupy 1,059,315,904 bytes and vision tensors
662,833,152 bytes. It was tested after the conservative 4B bound was refreshed, without bypassing it.

## Admission bound

The old 3,585 MiB historical bound was exceeded on this Mac. The retained 4-bit model now uses a
4,096 MiB process estimate, about 9.7% above the largest observed 3,732.8 MiB peak. The separate
1,024 MiB headroom and one-quarter physical-memory share remain unchanged. This means a fresh 4B
load requires 5 GiB reclaimable memory, and 16 GiB machines remain eligible. This is a conservative
estimate from this hardware and workload, not a universal peak guarantee or an enforceable MLX cap.
The memory requirement was raised for safety; it is not reported as a memory saving.

## Reproduce and evaluate

Build the benchmark with Xcode, using the same scratch path as the local bundle:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer Tools/metal-cache-guard.sh .build/huidict-swift
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build --scratch-path .build/huidict-swift -c release --product HuiDictModelBenchmark -Xswiftc -DHUIDICT_LOCAL_BUILD
python3 Tools/model-memory-benchmark.py --binary .build/huidict-swift/out/Products/Release/HuiDictModelBenchmark --model 4bit --cache-mib 256 --runs 5 --concurrent --out .build/model-experiments/reports/new-baseline
```

Use `--model 3bit` or `--model 2b4bit` with `--store .build/model-experiments/store` for a candidate.
The Swift benchmark's optional `--install` uses the hash-verifying downloader and Hugging Face for
candidate files; the pinned upstream license remains on ModelScope. Keep variants serial, use fresh
processes, and stop on a memory refusal. Never bypass the guard, force swap, clear live generation
buffers, or terminate unrelated applications. Do not promote a quantization based on file size,
five-run p95 peaks, or a blanket allowance for a number of grammar regressions.

Summaries are recorded in [model-memory-measurements.json](model-memory-measurements.json). Detailed
local reports remain in `.build/model-experiments/reports/`. Preserve the existing certificate,
fixed install path, strict peer checks, grants, and a rollback bundle for every update.

## Release checks

The required `make local-test` checks passed: 2,052 reported Swift tests across seven targets,
with unavailable optional licensed-dictionary fixtures skipped. `make test-tools` passed 65 tool
checks and 11 scheduler-reference checks. `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make local` also reran the Swift suite and built the signed bundle. The installed-app compatibility
gate accepted the original certificate and unchanged designated requirement before replacement.

Installed build `2026.1001.135627` retained the fixed `~/Applications/HuiDict.app` path and original
certificate. Its host SHA-256 is
`4fe3fcee724b177a103595c8cb969177fd0dae6f9bb4cc1e88312cb0b6d624c0`.
The previous build `2026.1001.111354` was retained as
`~/Applications/HuiDict.rollback-2026.1001.111354-memory.app`. Both bundle signatures and host hashes
were checked before and after the atomic swap.

The installed app passed all 13 existing actual-Qwen translation checks through its authenticated
XPC service. Three fresh `--permission-report` processes returned both grants. The installed
`--model-report`, without an idle override or a download, observed the default 120-second release:
2598 MiB while loaded, exit after 120.31 seconds, and 37 MiB in the fresh unloaded service.
Prewarming took 1.62 seconds; sense, translation, explanation, and pinned-model checks passed.

Native automation launched the installed app normally, but its UI state request timed out. Process
31205 was confirmed running at the fixed path. At 22:03:05, TCC (macOS's permission system) accepted
its original certificate requirement with status 0 and returned `Allowed (System Set)` for both
Accessibility and Screen Recording with HuiDict as the responsible process and `DB Action:None`.
Repeated Screen Recording decisions were allowed. No permission was reset or re-granted. This
establishes the normal app's own grants separately from terminal attribution. The global shortcut
and Option-hover gestures were not manually repeated in this update check.
