import importlib.util
import contextlib
import io
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch


module_path = Path(__file__).resolve().parents[1] / "model-memory-benchmark.py"
spec = importlib.util.spec_from_file_location("model_memory_benchmark", module_path)
benchmark = importlib.util.module_from_spec(spec)
spec.loader.exec_module(benchmark)


class ModelMemoryBenchmarkTests(unittest.TestCase):
    def run_cli(self, results, output):
        captured = io.StringIO()
        argv = ["benchmark", "--binary", "test-binary", "--model", "4bit", "--runs", str(len(results)),
                "--out", str(output)]
        with patch("sys.argv", argv), patch.object(benchmark.subprocess, "run", side_effect=results), \
                contextlib.redirect_stdout(captured):
            with self.assertRaises(SystemExit) as stopped:
                benchmark.main()
        return stopped.exception.code, [json.loads(line) for line in captured.getvalue().splitlines()]

    def test_child_failures_always_leave_a_structured_report(self):
        cases = [
            (subprocess.CompletedProcess([], 64, "", "invalid cases"), 64),
            (subprocess.CompletedProcess([], 0, "{broken", ""), 2),
            (subprocess.CompletedProcess([], 0, "[]", ""), 2),
            (subprocess.CompletedProcess([], 0, '{"unexpected":true}', ""), 2),
            (subprocess.CompletedProcess([], -9, "", "killed"), 137),
            (subprocess.TimeoutExpired([], 600, output=b"partial output", stderr=b"timeout evidence"), 2),
            (OSError("cannot start"), 2),
        ]
        for result, expected in cases:
            with self.subTest(result=result), tempfile.TemporaryDirectory() as scratch:
                output = Path(scratch) / "measurements"
                code, lines = self.run_cli([result], output)
                self.assertEqual(code, expected)
                self.assertEqual(lines[-1]["status"], "blocked")
                self.assertIn("error", lines[-1]["report"])
                self.assertEqual(json.loads((output / "run-1.json").read_text()), lines[-1]["report"])
                self.assertEqual(json.loads((output / "summary.json").read_text())["runs"], 0)
                self.assertTrue((output / "run-1.stdout.txt").is_file())
                self.assertTrue((output / "run-1.stderr.txt").is_file())

    def test_a_later_failed_run_preserves_completed_measurements(self):
        report = {
            "identifier": "pinned-test", "passed": True, "prewarmMilliseconds": 10,
            "memory": {"processPeakBytes": 100, "footprintBytes": 80, "gpuActiveBytes": 60,
                       "gpuCachedBytes": 10, "cacheLimitBytes": 64},
            "cases": [{"id": "word", "kind": "word", "milliseconds": 100, "screeningPassed": True}],
        }
        with tempfile.TemporaryDirectory() as scratch:
            output = Path(scratch) / "measurements"
            code, lines = self.run_cli([
                subprocess.CompletedProcess([], 0, json.dumps(report), ""),
                subprocess.CompletedProcess([], 2, '{"blocked":"not enough memory"}', ""),
            ], output)
            self.assertEqual(code, 2)
            self.assertEqual(lines[-1]["run"], 2)
            self.assertEqual(lines[-1]["summary"]["runs"], 1)
            self.assertEqual(lines[-1]["summary"]["wordMedianMilliseconds"], 100)
            self.assertEqual(json.loads((output / "run-1.json").read_text()), report)
            self.assertEqual(json.loads((output / "summary.json").read_text())["identifiers"], ["pinned-test"])

    def test_latency_excludes_sentence_and_explanation_work_and_keeps_failures(self):
        report = {
            "identifier": "pinned-test", "prewarmMilliseconds": 5000,
            "memory": {"processPeakBytes": 100 * 2**20, "footprintBytes": 80 * 2**20,
                       "gpuActiveBytes": 60 * 2**20, "gpuCachedBytes": 10 * 2**20,
                       "cacheLimitBytes": 64 * 2**20},
            "cases": [
                {"id": "slow-explanation", "kind": "explanation", "milliseconds": 10000, "screeningPassed": False},
                {"id": "word-a", "kind": "word", "milliseconds": 100, "screeningPassed": True},
                {"id": "word-b", "kind": "word", "milliseconds": 200, "screeningPassed": True},
            ],
        }
        result = benchmark.summarize([report])
        self.assertEqual(result["wordMedianMilliseconds"], 150)
        self.assertEqual(result["wordP95Milliseconds"], 200)
        self.assertEqual(result["screeningFailures"], [["slow-explanation"]])
        self.assertEqual(result["peakMiB"], [100])
        self.assertEqual(result["gpuActiveMiB"], [60])
        self.assertEqual(result["cacheLimitMiB"], [64])


if __name__ == "__main__":
    unittest.main()
