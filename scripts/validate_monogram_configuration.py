#!/usr/bin/env python3

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any


REQUIRED_KEYS = {
    "bundle_id",
    "api_id",
    "api_hash",
    "team_id",
    "app_center_id",
    "is_internal_build",
    "is_appstore_build",
    "appstore_id",
    "app_specific_url_scheme",
    "premium_iap_product_id",
    "enable_siri",
    "enable_icloud",
}

PLACEHOLDER_VALUES = {
    "YOUR_TELEGRAM_API_ID",
    "YOUR_TELEGRAM_API_HASH",

    "YOUR_APPLE_TEAM_ID",
}


def validate_configuration(configuration: dict[str, Any], allow_placeholders: bool = False) -> list[str]:
    errors: list[str] = []

    missing_keys = sorted(REQUIRED_KEYS - configuration.keys())
    if missing_keys:
        errors.append("missing required fields: " + ", ".join(missing_keys))

    unknown_keys = sorted(configuration.keys() - REQUIRED_KEYS)
    if unknown_keys:
        errors.append("unknown fields: " + ", ".join(unknown_keys))

    for key in REQUIRED_KEYS:
        if key in configuration and not isinstance(configuration[key], (str, bool)):
            errors.append(f"{key}: expected a string or boolean value")

    bundle_id = str(configuration.get("bundle_id", "")).strip()
    api_id = str(configuration.get("api_id", "")).strip()
    api_hash = str(configuration.get("api_hash", "")).strip()
    team_id = str(configuration.get("team_id", "")).strip()
    url_scheme = str(configuration.get("app_specific_url_scheme", "")).strip().lower()

    if not allow_placeholders:
        for key in ("api_id", "api_hash", "team_id"):
            if str(configuration.get(key, "")).strip() in PLACEHOLDER_VALUES:
                errors.append(f"{key}: replace the placeholder with a Monogram-specific value")

        if bundle_id.lower() == "com.yourcompany.monogram":
            errors.append("bundle_id: replace the example identifier")

    if api_id not in PLACEHOLDER_VALUES:
        if not api_id.isdigit() or int(api_id) <= 0:
            errors.append("api_id: expected a positive numeric identifier")
        elif api_id == "8":
            errors.append("api_id: the official Telegram identifier is forbidden")

    if api_hash not in PLACEHOLDER_VALUES and not re.fullmatch(r"[0-9a-fA-F]{32}", api_hash):
        errors.append("api_hash: expected a 32-character hexadecimal value")

    if team_id not in PLACEHOLDER_VALUES and not re.fullmatch(r"[A-Z0-9]{10}", team_id):
        errors.append("team_id: expected a 10-character Apple Team ID")

    if bundle_id and not re.fullmatch(r"[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+", bundle_id):
        errors.append("bundle_id: expected a reverse-DNS identifier")
    if "telegram" in bundle_id.lower() or bundle_id.lower().startswith("ph.telegra"):
        errors.append("bundle_id: official Telegram-style identifiers are forbidden")
    if url_scheme == "tg":
        errors.append("app_specific_url_scheme: the official tg scheme is forbidden for Monogram")
    if url_scheme and not re.fullmatch(r"[a-z][a-z0-9+.-]*", url_scheme):
        errors.append("app_specific_url_scheme: invalid URL scheme")

    for key in ("enable_siri", "enable_icloud"):
        if key in configuration and not isinstance(configuration[key], bool):
            errors.append(f"{key}: expected a JSON boolean")

    for key in ("is_internal_build", "is_appstore_build"):
        value = configuration.get(key)
        if value not in ("true", "false"):
            errors.append(f"{key}: expected the string true or false")

    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate a Monogram Telegram-iOS build configuration without printing secrets.")
    parser.add_argument("configuration", type=Path)
    parser.add_argument("--allow-placeholders", action="store_true", help="validate the tracked example template")
    arguments = parser.parse_args()

    try:
        with arguments.configuration.open("r", encoding="utf-8") as source:
            configuration = json.load(source)
    except (OSError, json.JSONDecodeError) as error:
        print(f"configuration is unreadable: {error}", file=sys.stderr)
        return 2

    if not isinstance(configuration, dict):
        print("configuration root must be a JSON object", file=sys.stderr)
        return 2

    errors = validate_configuration(configuration, allow_placeholders=arguments.allow_placeholders)
    if errors:
        for error in errors:
            print(f"error: {error}", file=sys.stderr)
        return 1

    print(f"configuration structure is valid: {arguments.configuration}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

