"""The native build must reject tampered assets and stale generated code."""
import importlib.util
from pathlib import Path
import shutil
import tempfile
import unittest

ROOT = Path(__file__).parents[2]
SPEC = importlib.util.spec_from_file_location("verify_liquefy", ROOT / "Tools/verify-liquefy.py")
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class LiquefyBundleTests(unittest.TestCase):
    def setUp(self):
        self.scratch = tempfile.TemporaryDirectory()
        self.repository = Path(self.scratch.name)
        shutil.copytree(ROOT / "Previews/LiquefyGlass/native", self.repository / "Previews/LiquefyGlass/native")
        for file in ("scripts/build-native.mjs", "package.json", "package-lock.json"):
            target = self.repository / "Previews/LiquefyGlass" / file
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / "Previews/LiquefyGlass" / file, target)
        self.resources = self.repository / "Resources/LiquefyGlass"
        shutil.copytree(ROOT / "Resources/LiquefyGlass", self.resources)

    def tearDown(self):
        self.scratch.cleanup()

    def test_current_offline_bundle_verifies(self):
        MODULE.verify(self.repository, self.resources)

    def test_modified_rendering_payload_is_rejected(self):
        (self.resources / "surface.html").write_text("tampered payload")
        with self.assertRaisesRegex(ValueError, "stale or modified"):
            MODULE.verify(self.repository, self.resources)

    def test_changed_source_requires_rebuilding_the_embedded_surface(self):
        path = self.repository / "Previews/LiquefyGlass/native/optics.js"
        path.write_text(path.read_text() + "\n// changed source\n")
        with self.assertRaisesRegex(ValueError, "stale or modified"):
            MODULE.verify(self.repository, self.resources)

    def test_missing_copyright_notices_are_rejected(self):
        (self.resources / "ThirdPartyNotices.txt").unlink()
        with self.assertRaises(OSError):
            MODULE.verify(self.repository, self.resources)
