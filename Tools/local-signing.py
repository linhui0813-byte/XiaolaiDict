#!/usr/bin/env python3
"""A persistent, per-Mac HuiDict signer. No system trust or keychain search-list changes."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import plistlib
import secrets
import shutil
import subprocess
import tempfile

DEFAULT = Path.home() / "Library/Application Support/HuiDict/Signing"
REPO = Path(__file__).resolve().parents[1]
INSTALLED = Path.home() / "Applications/HuiDict.app"


def run(arguments, secret=""):
    result = subprocess.run(arguments, capture_output=True, text=True)
    if result.returncode:
        message = result.stderr.strip()
        if secret:
            message = message.replace(secret, "[redacted]")
        raise RuntimeError(f"{Path(arguments[0]).name} failed: {message}")
    return result.stdout + result.stderr


def identity(directory):
    value = (directory / "identity.sha1").read_text().strip().upper()
    if len(value) != 40 or any(c not in "0123456789ABCDEF" for c in value):
        raise RuntimeError("Invalid local certificate fingerprint")
    return value


def verify(bundle, expected):
    run(["/usr/bin/codesign", "--verify", "--strict", str(bundle)])
    with tempfile.TemporaryDirectory(prefix="huidict-signature-") as scratch:
        prefix = Path(scratch) / "certificate"
        run(["/usr/bin/codesign", "-d", "--extract-certificates=" + str(prefix), str(bundle)])
        certificate = Path(str(prefix) + "0")
        if not certificate.exists() or hashlib.sha1(certificate.read_bytes()).hexdigest().upper() != expected.upper():
            raise RuntimeError("The code is not signed by the configured local certificate")


def designated_requirement(bundle):
    described = run(["/usr/bin/codesign", "-d", "-r-", str(bundle)])
    for line in described.splitlines():
        if line.startswith("designated => "):
            return line
    raise RuntimeError("The app has no designated signing requirement")


def check_update(bundle, expected, installed=INSTALLED):
    """Reject identity drift before replacing an app with working permission grants."""
    verify(bundle, expected)
    if not installed.exists():
        return  # First installation has no permission identity to preserve.
    verify(installed, expected)
    if designated_requirement(bundle) != designated_requirement(installed):
        raise RuntimeError("Update changes HuiDict's designated requirement; the current app was preserved")


def protect_existing_identity(apps):
    for app in apps:
        if app.exists():
            described = run(["/usr/bin/codesign", "-d", "-vv", str(app)])
            if "Signature=adhoc" not in described.splitlines():
                raise RuntimeError("A certificate-signed HuiDict already exists; recover its original Signing folder "
                                   "instead of generating a replacement identity")


def unlock(directory):
    password = (directory / "password").read_text().splitlines()[0]
    run(["/usr/bin/security", "unlock-keychain", "-p", password,
         str(directory / "local-signing.keychain-db")], password)


def setup(directory):
    if directory == REPO or REPO in directory.parents:
        raise RuntimeError("Signing credentials must be stored outside the repository")
    if (directory / "identity.sha1").exists():
        identity(directory)
        return
    if directory.exists() and any(directory.iterdir()):
        expected = ["password", "certificate.pem", "private-key.pem", "identity.p12",
                    "certificate.cnf", "local-signing.keychain-db"]
        if all((directory / name).is_file() for name in expected):
            unlock(directory)
            finalize(directory)
            return
        raise RuntimeError("Signing directory already contains files; no identity was replaced")
    protect_existing_identity([INSTALLED, REPO / ".build/HuiDict.app"])
    directory.mkdir(parents=True, exist_ok=True, mode=0o700)
    os.chmod(directory, 0o700)
    password = secrets.token_urlsafe(36)
    password_file = directory / "password"
    # OpenSSL reads two lines when passin and passout refer to the same file.
    password_file.write_text(password + "\n" + password + "\n")
    os.chmod(password_file, 0o600)
    openssl = shutil.which("openssl")
    if not openssl:
        raise RuntimeError("OpenSSL is required to create the local certificate")
    key, cert, package = (directory / name for name in ["private-key.pem", "certificate.pem", "identity.p12"])
    config = directory / "certificate.cnf"
    config.write_text("""[req]
distinguished_name = subject
x509_extensions = code_signing
prompt = no
[subject]
CN = HuiDict Local Development
O = HuiDict Local Development
[code_signing]
basicConstraints = critical,CA:TRUE
keyUsage = critical,digitalSignature,keyCertSign,cRLSign
extendedKeyUsage = codeSigning
""")
    run([openssl, "req", "-x509", "-newkey", "rsa:3072", "-keyout", str(key), "-out", str(cert),
         "-days", "3650", "-sha256", "-config", str(config), "-passout", "file:" + str(password_file)])
    export = [openssl, "pkcs12", "-export"]
    if "OpenSSL 3." in run([openssl, "version"]):
        export.append("-legacy")  # macOS imports the compatible PKCS#12 encoding.
    run(export + ["-in", str(cert), "-inkey", str(key), "-out", str(package),
                  "-passin", "file:" + str(password_file), "-passout", "file:" + str(password_file)])
    for path in [key, package]:
        os.chmod(path, 0o600)
    keychain = directory / "local-signing.keychain-db"
    before = run(["/usr/bin/security", "list-keychains", "-d", "user"])
    run(["/usr/bin/security", "create-keychain", "-p", password, str(keychain)], password)
    unlock(directory)
    run(["/usr/bin/security", "import", str(package), "-k", str(keychain), "-P", password,
         "-T", "/usr/bin/codesign"], password)
    os.chmod(keychain, 0o600)
    if run(["/usr/bin/security", "list-keychains", "-d", "user"]) != before:
        raise RuntimeError("The keychain search list changed unexpectedly")
    finalize(directory, openssl)


def finalize(directory, openssl=None):
    openssl = openssl or shutil.which("openssl")
    if not openssl:
        raise RuntimeError("OpenSSL is required to verify the certificate")
    cert = directory / "certificate.pem"
    keychain = directory / "local-signing.keychain-db"
    encoded = subprocess.check_output([openssl, "x509", "-in", str(cert), "-outform", "DER"])
    fingerprint = hashlib.sha1(encoded).hexdigest().upper()
    # Prove that two different signed builds keep a compatible designated requirement.
    with tempfile.TemporaryDirectory(prefix="huidict-signing-check-") as scratch:
        app = Path(scratch) / "SigningCheck.app"
        executable = app / "Contents/MacOS/SigningCheck"
        executable.parent.mkdir(parents=True)
        shutil.copyfile("/usr/bin/true", executable)
        executable.chmod(0o755)
        requirements, hashes = [], []
        for version in ["1", "2"]:
            with (app / "Contents/Info.plist").open("wb") as stream:
                plistlib.dump({"CFBundleIdentifier": "com.linhui.huidict.signing-check",
                              "CFBundleExecutable": "SigningCheck", "CFBundleVersion": version}, stream)
            run(["/usr/bin/codesign", "--force", "--options", "runtime", "--timestamp=none",
                 "--keychain", str(keychain), "--sign", fingerprint, str(app)])
            run(["/usr/bin/codesign", "--verify", "--strict", str(app)])
            verify(app, fingerprint)
            requirements.append(run(["/usr/bin/codesign", "-d", "-r-", str(app)]))
            hashes.append(hashlib.sha256(executable.read_bytes()).hexdigest())
        if requirements[0] != requirements[1] or hashes[0] == hashes[1]:
            raise RuntimeError("The signing identity did not remain stable across builds")
    (directory / "identity.sha1").write_text(fingerprint + "\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["setup", "unlock", "status", "verify", "check-update"])
    parser.add_argument("bundle", nargs="?", type=Path)
    parser.add_argument("--directory", type=Path, default=DEFAULT)
    parser.add_argument("--identity")
    parser.add_argument("--installed", type=Path, default=INSTALLED)
    args = parser.parse_args()
    directory = args.directory.expanduser().resolve()
    try:
        if args.command == "verify":
            if not args.bundle or not args.identity:
                raise RuntimeError("verify requires a bundle and --identity fingerprint")
            verify(args.bundle, args.identity)
            return
        if args.command == "check-update":
            if not args.bundle:
                raise RuntimeError("check-update requires a bundle")
            check_update(args.bundle, args.identity or identity(directory), args.installed.expanduser().resolve())
            print("Update preserves HuiDict's signing identity")
            return
        if args.command == "setup":
            setup(directory)
        elif args.command == "unlock":
            unlock(directory)
            return
        print(json.dumps({"identity": identity(directory), "keychain": str(directory / "local-signing.keychain-db")}))
    except (RuntimeError, OSError) as error:
        parser.exit(1, str(error) + "\n")


if __name__ == "__main__":
    main()
