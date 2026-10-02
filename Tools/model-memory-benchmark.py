#!/usr/bin/env python3
"""Run serial, fresh-process local-model measurements without changing app settings."""
import argparse
import json
from pathlib import Path
import statistics
import subprocess


def summarize(reports):
    warm = [row["milliseconds"] for report in reports for row in report["cases"] if row["kind"] == "word"]
    warm.sort()
    return {
        "runs": len(reports),
        "identifiers": sorted({report["identifier"] for report in reports}),
        "peakMiB": [round(report["memory"]["processPeakBytes"] / 2**20, 1) for report in reports],
        "steadyMiB": [round(report["memory"]["footprintBytes"] / 2**20, 1) for report in reports],
        "gpuActiveMiB": [round(report["memory"]["gpuActiveBytes"] / 2**20, 1) for report in reports],
        "gpuCachedMiB": [round(report["memory"]["gpuCachedBytes"] / 2**20, 1) for report in reports],
        "cacheLimitMiB": [round(report["memory"]["cacheLimitBytes"] / 2**20, 1) for report in reports],
        "prewarmMilliseconds": [round(report["prewarmMilliseconds"], 1) for report in reports],
        "wordMedianMilliseconds": round(statistics.median(warm), 1) if warm else None,
        "wordP95Milliseconds": round(warm[max(0, (95 * len(warm) + 99) // 100 - 1)], 1) if warm else None,
        "screeningFailures": [[row["id"] for row in report["cases"] if not row["screeningPassed"]] for report in reports],
        "note": "Screening checks are not a broad accuracy or latency guarantee. Inspect semantic differences separately.",
    }



def text_output(value):
    if isinstance(value, bytes):
        return value.decode("utf-8", errors="replace")
    return value or ""


def measure(command):
    try:
        result = subprocess.run(command, capture_output=True, text=True, timeout=600)
    except subprocess.TimeoutExpired as exc:
        return text_output(exc.stdout), text_output(exc.stderr), {"error": "benchmark timed out", "timeoutSeconds": 600}, 2
    except OSError:
        return "", "", {"error": "benchmark could not be started"}, 2
    stdout, stderr, code = result.stdout, result.stderr, result.returncode
    try:
        report = json.loads(stdout)
        if not isinstance(report, dict):
            raise ValueError("expected an object")
        if not code and "blocked" not in report and "error" not in report:
            summarize([report])
            if type(report["passed"]) is not bool:
                raise ValueError("expected a screening result")
    except (json.JSONDecodeError, KeyError, TypeError, ValueError):
        report = {"error": "benchmark produced no valid measurement report", "returncode": code}
    return stdout, stderr, report, code


def save_summary(directory, reports):
    summary = summarize(reports)
    (directory / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    return summary


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--binary", type=Path, required=True)
    parser.add_argument("--model", choices=("4bit", "3bit", "2b4bit"), required=True)
    parser.add_argument("--store", type=Path)
    parser.add_argument("--cases", type=Path, default=Path("Tools/ModelBenchmark/cases.json"))
    parser.add_argument("--cache-mib", type=int, choices=range(16, 257), default=256)
    parser.add_argument("--runs", type=int, choices=range(1, 11), default=3)
    parser.add_argument("--concurrent", action="store_true")
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=False)
    reports = []
    for run in range(1, args.runs + 1):
        command = [str(args.binary.resolve()), "--model", args.model, "--cases", str(args.cases.resolve()),
                   "--cache-mib", str(args.cache_mib)]
        if args.store:
            command.extend(("--store", str(args.store.resolve())))
        if args.concurrent:
            command.append("--concurrent")
        stdout, stderr, report, code = measure(command)
        (args.out / f"run-{run}.json").write_text(json.dumps(report, indent=2) + "\n")
        (args.out / f"run-{run}.stdout.txt").write_text(stdout)
        (args.out / f"run-{run}.stderr.txt").write_text(stderr)
        if code or "blocked" in report or "error" in report:
            summary = save_summary(args.out, reports)
            print(json.dumps({"run": run, "status": "blocked", "report": report,
                              "returncode": code, "summary": summary}), flush=True)
            raise SystemExit((128 - code if code < 0 else code) or 2)
        reports.append(report)
        print(json.dumps({"run": run, "model": args.model, "screeningPassed": report["passed"],
                          "peakMiB": round(report["memory"]["processPeakBytes"] / 2**20, 1)}), flush=True)
    summary = save_summary(args.out, reports)
    print(json.dumps(summary), flush=True)


if __name__ == "__main__":
    main()
