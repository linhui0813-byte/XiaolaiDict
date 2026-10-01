import importlib.util
from pathlib import Path
import unittest


module_path = Path(__file__).resolve().parents[1] / "model-memory-benchmark.py"
spec = importlib.util.spec_from_file_location("model_memory_benchmark", module_path)
benchmark = importlib.util.module_from_spec(spec)
spec.loader.exec_module(benchmark)


class ModelMemoryBenchmarkTests(unittest.TestCase):
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
