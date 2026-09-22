#!/usr/bin/env python3
"""Rebuild the fake provisioning profiles for a custom bundle id.

The profiles tracked in `build-system/fake-codesigning/profiles` are the stock
Telegram ones: they are issued for `C67CF9S4VU.ph.telegra.Telegraph`. Build
configurations are matched to a profile by the `<team_id>.<bundle_id>` prefix of
its `application-identifier` (see `copy_profiles_from_directory` in
`build-system/Make/BuildConfiguration.py`), so a build using any other bundle id
finds no profiles at all.

This script rewrites each tracked profile for the team id and bundle id of a
given configuration and re-signs it with the tracked self-signed certificate.
The result is only good for local/simulator builds and for sideloading after a
re-sign (Sideloadly, AltStore) — it carries no Apple-issued authority.
"""

import argparse
import plistlib
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

SOURCE_TEAM_ID = "C67CF9S4VU"
SOURCE_BUNDLE_ID = "ph.telegra.Telegraph"


def extract_plist(profile: bytes) -> bytes:
    start = profile.find(b"<?xml")
    end = profile.find(b"</plist>")
    if start == -1 or end == -1:
        raise ValueError("profile does not contain an embedded plist")
    return profile[start:end + len(b"</plist>")]


def rewrite(payload: bytes, team_id: str, bundle_id: str) -> bytes:
    """Substitute the identity strings, longest pattern first."""
    replacements = [
        (f"{SOURCE_TEAM_ID}.{SOURCE_BUNDLE_ID}", f"{team_id}.{bundle_id}"),
        (f"group.{SOURCE_BUNDLE_ID}", f"group.{bundle_id}"),
        (f"iCloud.{SOURCE_BUNDLE_ID}", f"iCloud.{bundle_id}"),
        (f"{SOURCE_TEAM_ID}.group.{SOURCE_BUNDLE_ID}", f"{team_id}.group.{bundle_id}"),
        (SOURCE_BUNDLE_ID, bundle_id),
        (SOURCE_TEAM_ID, team_id),
    ]
    text = payload.decode("utf-8")
    for source, destination in replacements:
        text = text.replace(source, destination)
    return text.encode("utf-8")


def sign(payload: bytes, certificate: Path, key: Path, destination: Path) -> None:
    with tempfile.NamedTemporaryFile(suffix=".plist", delete=False) as handle:
        handle.write(payload)
        payload_path = Path(handle.name)
    try:
        subprocess.run(
            [
                "openssl", "smime", "-sign",
                "-in", str(payload_path),
                "-out", str(destination),
                "-outform", "DER",
                "-nodetach",
                "-signer", str(certificate),
                "-inkey", str(key),
                "-md", "sha256",
            ],
            check=True,
        )
    finally:
        payload_path.unlink(missing_ok=True)


def split_pkcs12(pkcs12_path: Path, work_dir: Path) -> tuple[Path, Path]:
    """Export the certificate and private key of the self-signed .p12."""
    combined = work_dir / "identity.pem"
    for extra in (["-legacy"], []):
        result = subprocess.run(
            ["openssl", "pkcs12", "-in", str(pkcs12_path), "-passin", "pass:",
             "-nodes", "-out", str(combined)] + extra,
            capture_output=True,
        )
        if result.returncode == 0:
            break
    else:
        raise SystemExit("unable to read {}: {}".format(pkcs12_path, result.stderr.decode(errors="replace")))
    return combined, combined


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--configuration", type=Path, required=True, help="build configuration JSON to read team_id/bundle_id from")
    parser.add_argument("--source", type=Path, default=Path("build-system/fake-codesigning"))
    parser.add_argument("--destination", type=Path, required=True, help="directory to write the regenerated material into")
    arguments = parser.parse_args()

    import json
    configuration = json.loads(arguments.configuration.read_text(encoding="utf-8"))
    team_id = str(configuration["team_id"]).strip()
    bundle_id = str(configuration["bundle_id"]).strip()
    if not re.fullmatch(r"[A-Z0-9]{10}", team_id):
        raise SystemExit(f"team_id must be a 10-character Apple Team ID, got {team_id!r}")

    destination = arguments.destination
    if destination.exists():
        shutil.rmtree(destination)
    (destination / "profiles").mkdir(parents=True)
    shutil.copytree(arguments.source / "certs", destination / "certs")

    with tempfile.TemporaryDirectory() as work_dir:
        certificate, key = split_pkcs12(arguments.source / "certs" / "SelfSigned.p12", Path(work_dir))

        for profile_path in sorted((arguments.source / "profiles").glob("*.mobileprovision")):
            payload = rewrite(extract_plist(profile_path.read_bytes()), team_id, bundle_id)
            output_path = destination / "profiles" / profile_path.name
            sign(payload, certificate, key, output_path)

            written = plistlib.loads(extract_plist(output_path.read_bytes()))
            print("{}: {}".format(profile_path.name, written["Entitlements"]["application-identifier"]))

    print("regenerated fake codesigning material in {}".format(destination))
    return 0


if __name__ == "__main__":
    sys.exit(main())
