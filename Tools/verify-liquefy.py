#!/usr/bin/env python3
"""Reject a missing, modified, or stale offline glass bundle before signing."""
import argparse
import hashlib
import json
from pathlib import Path


def verify(repository: Path, resources: Path) -> None:
    manifest = json.loads((resources / "manifest.json").read_text())
    if manifest.get("library") != "@liquefy-ui/react" or manifest.get("version") != "1.0.0":
        raise ValueError("unexpected Liquefy library/version")
    expected_inputs = {
        "Previews/LiquefyGlass/native/surface.jsx", "Previews/LiquefyGlass/native/surface.css",
        "Previews/LiquefyGlass/native/optics.js", "Previews/LiquefyGlass/scripts/build-native.mjs",
        "Previews/LiquefyGlass/package.json", "Previews/LiquefyGlass/package-lock.json",
    }
    if set(manifest.get("inputs", {})) != expected_inputs:
        raise ValueError("incomplete Liquefy source manifest")
    expected_files = {"surface.html", "ThirdPartyNotices.txt"}
    if set(manifest.get("files", {})) != expected_files:
        raise ValueError("incomplete Liquefy resource manifest")
    for mapping, base in ((manifest["inputs"], repository), (manifest["files"], resources)):
        for name, expected in mapping.items():
            actual = hashlib.sha256((base / name).read_bytes()).hexdigest()
            if actual != expected:
                raise ValueError(f"stale or modified Liquefy input: {name}; run npm run build:native")
    declared = json.loads((repository / "Previews/LiquefyGlass/package.json").read_text())["dependencies"]
    for name in ("@liquefy-ui/react", "@liquefy-ui/core"):
        if declared.get(name) != manifest.get("packages", {}).get(name):
            raise ValueError(f"Liquefy package pin differs from the embedded bundle: {name}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("resources", type=Path)
    args = parser.parse_args()
    try:
        verify(Path(__file__).resolve().parent.parent, args.resources)
    except (OSError, ValueError, KeyError) as error:
        parser.exit(1, f"error: {error}\n")
