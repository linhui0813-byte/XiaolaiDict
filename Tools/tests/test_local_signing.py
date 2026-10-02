"""Protect the local signer boundary without creating credentials during routine unit tests."""
import importlib.util
import os
from pathlib import Path
import re
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
            environment = os.environ | {"HUIDICT_LOCAL_BUILD": "1", "HUIDICT_SIGNING_DIR": scratch,
                                        "XIAOLAIDICT_BUILD_NUMBER": ""}
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


class BundleResourceVerificationTests(unittest.TestCase):
    def test_an_empty_build_resource_list_reports_the_unexpected_bundle(self):
        source = (SIGNING.REPO / "Tools/build-bundle.sh").read_text()
        function = re.search(r"(?ms)^verify_required_files\(\).*?^}\n", source)
        self.assertIsNotNone(function)
        with tempfile.TemporaryDirectory() as scratch:
            bundle = Path(scratch) / "Fixture.app"
            xpc = "Contents/XPCServices/Dictionary.xpc"
            model = "Contents/XPCServices/Model.xpc"
            for relative in ["Contents/MacOS/Fixture", f"{xpc}/Contents/MacOS/Dictionary",
                             f"{model}/Contents/MacOS/Model"]:
                file = bundle / relative
                file.parent.mkdir(parents=True, exist_ok=True)
                file.write_text("fixture")
                file.chmod(0o755)
            for relative in ["Contents/Info.plist", "Contents/Resources/Assets.car",
                             "Contents/Resources/MenuBarIcon.svg", "Contents/Resources/Notices.txt",
                             f"{xpc}/Contents/Info.plist", f"{model}/Contents/Info.plist",
                             f"{model}/Contents/Resources/Unexpected.bundle/default.metallib"]:
                file = bundle / relative
                file.parent.mkdir(parents=True, exist_ok=True)
                file.write_text("fixture")
            commands = r'''
set -euo pipefail
APP_NAME=Fixture SERVICE=Dictionary MODEL_SERVICE=Model NOTICES=Notices.txt
XPC_PATH=Contents/XPCServices/Dictionary.xpc
MODEL_XPC_PATH=Contents/XPCServices/Model.xpc
METALLIB_PATH=$MODEL_XPC_PATH/Contents/Resources/Unexpected.bundle/default.metallib
BUNDLE_LIST=()
resolve_products() { BUNDLE_LIST=(); }
catalog_languages() { :; }
'''
            result = subprocess.run(
                ["/bin/bash", "-c", commands + function.group(0) + '\nverify_required_files "$1"',
                 "bundle-fixture", str(bundle)], capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("the model service carries Unexpected.bundle, which this build did not produce",
                          result.stdout)
            self.assertNotIn("unbound variable", result.stderr)


class SigningRetryTests(unittest.TestCase):
    def sign(self, stamp, succeeds_on=0):
        source = (SIGNING.REPO / "Tools/build-bundle.sh").read_text()
        function = re.search(r"(?ms)^sign_part\(\).*?^}\n", source)
        self.assertIsNotNone(function, "the real signing function was not found")
        # Execute the production function with fake commands: no credentials, network, signing
        # changes or actual backoff waits occur in these tests.
        commands = r'''
set -euo pipefail
readonly LOCAL_BUILD=1 LOCAL_KEYCHAIN=fixture-keychain XIAOLAIDICT_SIGN_ID=fixture-identity SIGN_TRIES=5
codesign() {
    local count=0
    [ ! -f "$TEST_SIGN_CALLS" ] || count=$(cat "$TEST_SIGN_CALLS")
    count=$((count + 1))
    printf '%s' "$count" > "$TEST_SIGN_CALLS"
    if (( count == TEST_SIGN_SUCCEEDS_ON )); then return 0; fi
    echo 'fixture signing failure' >&2
    return 37
}
sleep() { printf '%s\n' "$1" >> "$TEST_SIGN_SLEEPS"; }
note() { printf '%s\n' "$*"; }
'''
        with tempfile.TemporaryDirectory() as scratch:
            calls = Path(scratch) / "calls"
            sleeps = Path(scratch) / "sleeps"
            environment = os.environ | {"TEST_SIGN_CALLS": str(calls), "TEST_SIGN_SLEEPS": str(sleeps),
                                        "TEST_SIGN_SUCCEEDS_ON": str(succeeds_on)}
            result = subprocess.run(["/bin/bash", "-c", commands + function.group(0) + '\nsign_part "$1" "$2"',
                                     "signing-fixture", stamp, "Fixture.app"],
                                    env=environment, capture_output=True, text=True)
            return result, int(calls.read_text()), sleeps.read_text().splitlines() if sleeps.exists() else []

    def test_offline_signing_fails_once_and_keeps_its_diagnostic(self):
        result, calls, sleeps = self.sign("--timestamp=none")
        self.assertEqual(result.returncode, 37)
        self.assertEqual(calls, 1)
        self.assertEqual(sleeps, [])
        self.assertIn("fixture signing failure", result.stderr)
        self.assertNotIn("retrying", result.stdout)

    def test_timestamp_signing_retains_bounded_retries_and_each_diagnostic(self):
        result, calls, sleeps = self.sign("--timestamp")
        self.assertEqual(result.returncode, 37)
        self.assertEqual(calls, 5)
        self.assertEqual(sleeps, ["2", "4", "6", "8"])
        self.assertEqual(result.stderr.count("fixture signing failure"), 5)

    def test_a_transient_timestamp_failure_can_succeed_on_the_next_attempt(self):
        result, calls, sleeps = self.sign("--timestamp", succeeds_on=2)
        self.assertEqual(result.returncode, 0)
        self.assertEqual(calls, 2)
        self.assertEqual(sleeps, ["2"])
