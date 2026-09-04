import json
import sys
import unittest
from pathlib import Path


SCRIPTS_DIRECTORY = Path(__file__).resolve().parents[1]
REPOSITORY_ROOT = SCRIPTS_DIRECTORY.parent
sys.path.insert(0, str(SCRIPTS_DIRECTORY))

from validate_monogram_configuration import validate_configuration


class ValidateMonogramConfigurationTests(unittest.TestCase):
    def valid_configuration(self) -> dict[str, object]:
        return {
            "bundle_id": "com.example.monogram.dev",
            "api_id": "123456",
            "api_hash": "0123456789abcdef0123456789abcdef",
            "team_id": "ABCDE12345",
            "app_center_id": "0",
            "is_internal_build": "true",
            "is_appstore_build": "false",
            "appstore_id": "0",
            "app_specific_url_scheme": "monogram-dev",
            "premium_iap_product_id": "",
            "enable_siri": False,
            "enable_icloud": False,
        }

    def test_valid_custom_configuration(self) -> None:
        self.assertEqual(validate_configuration(self.valid_configuration()), [])

    def test_tracked_example_structure(self) -> None:
        path = REPOSITORY_ROOT / "build-system" / "monogram-development-configuration.example.json"
        configuration = json.loads(path.read_text(encoding="utf-8"))
        self.assertEqual(validate_configuration(configuration, allow_placeholders=True), [])

    def test_placeholders_are_rejected_for_real_builds(self) -> None:
        path = REPOSITORY_ROOT / "build-system" / "monogram-development-configuration.example.json"
        configuration = json.loads(path.read_text(encoding="utf-8"))
        self.assertTrue(validate_configuration(configuration))

    def test_official_telegram_identity_is_rejected(self) -> None:
        configuration = self.valid_configuration()
        configuration["api_id"] = "8"
        configuration["bundle_id"] = "org.telegram.Telegram-iOS"
        configuration["app_specific_url_scheme"] = "tg"

        errors = validate_configuration(configuration)
        self.assertTrue(any("api_id" in error for error in errors))
        self.assertTrue(any("bundle_id" in error for error in errors))
        self.assertTrue(any("app_specific_url_scheme" in error for error in errors))

    def test_errors_never_contain_api_hash(self) -> None:
        configuration = self.valid_configuration()
        secret_hash = "fedcba9876543210fedcba9876543210"
        configuration["api_hash"] = secret_hash
        configuration["api_id"] = "8"

        self.assertNotIn(secret_hash, "\n".join(validate_configuration(configuration)))


if __name__ == "__main__":
    unittest.main()

