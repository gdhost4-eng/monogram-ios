import unittest
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
APP_DELEGATE = REPOSITORY_ROOT / "submodules" / "TelegramUI" / "Sources" / "AppDelegate.swift"


class SideloadStartupSourceTests(unittest.TestCase):
    def test_missing_app_group_uses_application_sandbox(self) -> None:
        source = APP_DELEGATE.read_text(encoding="utf-8")

        self.assertIn("if let maybeAppGroupUrl", source)
        self.assertIn(".applicationSupportDirectory", source)
        self.assertIn('appendingPathComponent("Monogram", isDirectory: true)', source)
        self.assertIn("createDirectory(at: fallbackUrl", source)
        self.assertNotIn("guard let appGroupUrl = maybeAppGroupUrl", source)

    def test_background_sessions_only_use_an_available_app_group(self) -> None:
        source = APP_DELEGATE.read_text(encoding="utf-8")
        availability_check = (
            "FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupName) != nil"
        )

        self.assertIn(availability_check, source)
        self.assertLess(
            source.index(availability_check),
            source.index("configuration.sharedContainerIdentifier = appGroupName"),
        )


if __name__ == "__main__":
    unittest.main()
