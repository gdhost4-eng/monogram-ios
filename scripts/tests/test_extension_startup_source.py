import unittest
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
SHARE = REPOSITORY_ROOT / "Telegram" / "Share" / "ShareRootController.swift"
NOTIFICATION_CONTENT = (
    REPOSITORY_ROOT / "Telegram" / "NotificationContent" / "NotificationViewController.swift"
)
NOTIFICATION_SERVICE = (
    REPOSITORY_ROOT / "Telegram" / "NotificationService" / "Sources" / "NotificationService.swift"
)
WORKFLOW = REPOSITORY_ROOT / ".github" / "workflows" / "build.yml"
TELEGRAM_BUILD = REPOSITORY_ROOT / "Telegram" / "BUILD"


class ExtensionStartupSourceTests(unittest.TestCase):
    def test_sideload_workflow_disables_extensions(self) -> None:
        workflow = WORKFLOW.read_text(encoding="utf-8")
        build = TELEGRAM_BUILD.read_text(encoding="utf-8")

        self.assertIn("--disableExtensions", workflow)
        self.assertIn('name = "disableExtensions"', build)
        self.assertIn('":disableExtensionsSetting": []', build)

    def test_ui_extensions_render_explicit_unavailable_state(self) -> None:
        for path in (SHARE, NOTIFICATION_CONTENT):
            source = path.read_text(encoding="utf-8")
            self.assertNotIn("Bundle.main.bundleIdentifier!", source)
            self.assertIn("showUnavailableState()", source)
            self.assertIn("shared application container is not configured", source)

    def test_notification_service_completes_when_app_group_is_unavailable(self) -> None:
        source = NOTIFICATION_SERVICE.read_text(encoding="utf-8")
        guard_index = source.index(
            "guard FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupName) != nil"
        )
        completion_index = source.index("contentHandler(request.content)", guard_index)
        handler_index = source.index("self.impl = QueueLocalObject", guard_index)

        self.assertLess(completion_index, handler_index)


if __name__ == "__main__":
    unittest.main()
