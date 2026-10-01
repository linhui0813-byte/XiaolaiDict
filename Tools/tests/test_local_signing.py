"""Protect the local signer boundary without creating credentials during routine unit tests."""
import importlib.util
from pathlib import Path
import sys
import tempfile
import unittest

SPEC = importlib.util.spec_from_file_location("local_signing", Path(__file__).parents[1] / "local-signing.py")
SIGNING = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(SIGNING)


class LocalSigningTests(unittest.TestCase):
    def test_credentials_cannot_be_created_inside_the_repository(self):
        with self.assertRaisesRegex(RuntimeError, "outside the repository"):
            SIGNING.setup(SIGNING.REPO / ".build/signing-test")

    def test_a_partial_directory_does_not_replace_existing_credentials(self):
        with tempfile.TemporaryDirectory() as scratch:
            directory = Path(scratch)
            retained = directory / "private-key.pem"
            retained.write_text("retained fixture")
            with self.assertRaisesRegex(RuntimeError, "no identity was replaced"):
                SIGNING.setup(directory)
            self.assertEqual(retained.read_text(), "retained fixture")

    def test_a_malformed_fingerprint_is_refused(self):
        with tempfile.TemporaryDirectory() as scratch:
            directory = Path(scratch)
            (directory / "identity.sha1").write_text("not a certificate fingerprint")
            with self.assertRaisesRegex(RuntimeError, "Invalid local certificate"):
                SIGNING.identity(directory)

    def test_subprocess_failures_redact_the_password(self):
        with self.assertRaises(RuntimeError) as caught:
            SIGNING.run([sys.executable, "-c", "import sys; sys.stderr.write('fixture-password'); sys.exit(1)"],
                        secret="fixture-password")
        self.assertNotIn("fixture-password", str(caught.exception))
        self.assertIn("[redacted]", str(caught.exception))
