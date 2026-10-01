"""Protect the local signer boundary without creating credentials during routine unit tests."""
import importlib.util
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location("local_signing", Path(__file__).parents[1] / "local-signing.py")
SIGNING = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(SIGNING)


class LocalSigningTests(unittest.TestCase):
    def test_build_stops_before_publication_when_the_signer_is_missing(self):
        with tempfile.TemporaryDirectory() as scratch:
            environment = os.environ | {"HUIDICT_LOCAL_BUILD": "1", "HUIDICT_SIGNING_DIR": scratch}
            result = subprocess.run(["bash", str(SIGNING.REPO / "Tools/build-bundle.sh"), "build"],
                                    env=environment, capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("ad-hoc fallback is disabled", result.stderr)
            self.assertNotIn("published", result.stdout)

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

    def test_setup_refuses_to_replace_an_existing_certificate_identity(self):
        with tempfile.TemporaryDirectory() as scratch:
            root = Path(scratch)
            installed = root / "HuiDict.app"
            installed.mkdir()
            directory = root / "Signing"
            with patch.object(SIGNING, "INSTALLED", installed), \
                 patch.object(SIGNING, "run", return_value="Authority=HuiDict Local Development\n"):
                with self.assertRaisesRegex(RuntimeError, "recover its original Signing folder"):
                    SIGNING.setup(directory)
            self.assertFalse(directory.exists(), "a refused setup must not create replacement credentials")

    def test_a_different_requirement_is_rejected_even_with_the_same_certificate(self):
        with tempfile.TemporaryDirectory() as scratch:
            installed = Path(scratch) / "HuiDict.app"
            installed.mkdir()
            candidate = Path(scratch) / "Update.app"
            with patch.object(SIGNING, "verify"), \
                 patch.object(SIGNING, "designated_requirement", side_effect=["identifier new", "identifier old"]):
                with self.assertRaisesRegex(RuntimeError, "changes HuiDict's designated requirement"):
                    SIGNING.check_update(candidate, "A" * 40, installed)

    def test_an_existing_app_signed_by_another_certificate_is_rejected(self):
        with tempfile.TemporaryDirectory() as scratch:
            installed = Path(scratch) / "HuiDict.app"
            installed.mkdir()
            candidate = Path(scratch) / "Update.app"
            with patch.object(SIGNING, "verify", side_effect=[None, RuntimeError("different certificate")]), \
                 patch.object(SIGNING, "designated_requirement") as requirement:
                with self.assertRaisesRegex(RuntimeError, "different certificate"):
                    SIGNING.check_update(candidate, "A" * 40, installed)
                requirement.assert_not_called()

    def test_a_compatible_update_checks_both_signatures_and_requirements(self):
        with tempfile.TemporaryDirectory() as scratch:
            installed = Path(scratch) / "HuiDict.app"
            installed.mkdir()
            candidate = Path(scratch) / "Update.app"
            with patch.object(SIGNING, "verify") as verify, \
                 patch.object(SIGNING, "designated_requirement", return_value="identifier same and certificate root same"):
                SIGNING.check_update(candidate, "A" * 40, installed)
                self.assertEqual(verify.call_args_list[0].args, (candidate, "A" * 40))
                self.assertEqual(verify.call_args_list[1].args, (installed, "A" * 40))

    def test_first_installation_still_requires_a_valid_candidate_signature(self):
        with tempfile.TemporaryDirectory() as scratch:
            candidate = Path(scratch) / "Update.app"
            with patch.object(SIGNING, "verify", side_effect=RuntimeError("invalid candidate")):
                with self.assertRaisesRegex(RuntimeError, "invalid candidate"):
                    SIGNING.check_update(candidate, "A" * 40, Path(scratch) / "missing.app")
