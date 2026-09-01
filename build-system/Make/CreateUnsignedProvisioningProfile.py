#!/usr/bin/env python3

"""Create a disposable provisioning profile for an IPA that will be re-signed.

The profile is only accepted by the local rules_apple packaging step. It is not
an Apple-issued profile and must never be used to distribute an application.
"""

import argparse
import plistlib
import subprocess
import tempfile
import uuid
from pathlib import Path


def run(*arguments: str) -> None:
    subprocess.run(arguments, check=True)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--template", type=Path, required=True)
    parser.add_argument("--p12", type=Path, required=True)
    parser.add_argument("--team-id", required=True)
    parser.add_argument("--bundle-id", required=True)
    parser.add_argument("--output", type=Path, required=True)
    arguments = parser.parse_args()

    with tempfile.TemporaryDirectory() as temporary_directory:
        temporary_path = Path(temporary_directory)
        template_plist = temporary_path / "template.plist"
        signing_key = temporary_path / "signing.pem"

        run(
            "openssl", "smime", "-inform", "der", "-verify", "-noverify",
            "-in", str(arguments.template), "-out", str(template_plist)
        )
        with template_plist.open("rb") as source:
            profile = plistlib.load(source)

        app_identifier = f"{arguments.team_id}.{arguments.bundle_id}"
        entitlements = profile["Entitlements"]
        entitlements["application-identifier"] = app_identifier
        entitlements["com.apple.developer.team-identifier"] = arguments.team_id
        entitlements["keychain-access-groups"] = [app_identifier]
        entitlements["get-task-allow"] = True
        entitlements["aps-environment"] = "development"
        profile["ApplicationIdentifierPrefix"] = [arguments.team_id]
        profile["TeamIdentifier"] = [arguments.team_id]
        profile["Name"] = "Monogram temporary sideload profile"
        profile["UUID"] = str(uuid.uuid4()).upper()

        with template_plist.open("wb") as destination:
            plistlib.dump(profile, destination)

        run(
            "openssl", "pkcs12", "-legacy", "-in", str(arguments.p12), "-nodes",
            "-passin", "pass:", "-out", str(signing_key)
        )
        arguments.output.parent.mkdir(parents=True, exist_ok=True)
        run(
            "openssl", "smime", "-sign", "-binary", "-in", str(template_plist),
            "-signer", str(signing_key), "-inkey", str(signing_key),
            "-outform", "der", "-nodetach", "-out", str(arguments.output)
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
