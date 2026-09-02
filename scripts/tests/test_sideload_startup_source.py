import unittest
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
APP_DELEGATE = REPOSITORY_ROOT / "submodules" / "TelegramUI" / "Sources" / "AppDelegate.swift"
STARTUP_STATE = REPOSITORY_ROOT / "submodules" / "TelegramUI" / "Sources" / "ApplicationStartupState.swift"
ACCOUNT_MANAGER = (
    REPOSITORY_ROOT
    / "submodules"
    / "TelegramCore"
    / "Sources"
    / "AccountManager"
    / "AccountManagerImpl.swift"
)
SHARED_NOTIFICATION_MANAGER = (
    REPOSITORY_ROOT / "submodules" / "TelegramUI" / "Sources" / "SharedNotificationManager.swift"
)
SHARED_WAKEUP_MANAGER = (
    REPOSITORY_ROOT / "submodules" / "TelegramUI" / "Sources" / "SharedWakeupManager.swift"
)
SQLITE_VALUE_BOX = REPOSITORY_ROOT / "submodules" / "Postbox" / "Sources" / "SqliteValueBox.swift"
STARTUP_ENVIRONMENT = (
    REPOSITORY_ROOT
    / "submodules"
    / "TelegramUI"
    / "Sources"
    / "ApplicationStartupEnvironment.swift"
)


class SideloadStartupSourceTests(unittest.TestCase):
    def test_missing_app_group_uses_application_sandbox(self) -> None:
        source = STARTUP_ENVIRONMENT.read_text(encoding="utf-8")

        self.assertIn("if let appGroupUrl", source)
        self.assertIn(".applicationSupportDirectory", source)
        self.assertIn('"Monogram"', source)
        self.assertIn("fileManager.createDirectory", source)
        self.assertIn("usesFallbackContainer = true", source)
        self.assertIn(".appendingPathComponent(baseAppBundleId", source)

    def test_background_sessions_only_use_an_available_app_group(self) -> None:
        source = STARTUP_ENVIRONMENT.read_text(encoding="utf-8")
        availability_check = (
            "fileManager.containerURL(\n"
            "            forSecurityApplicationGroupIdentifier: appGroupName\n"
            "        ) != nil"
        )

        self.assertIn(availability_check, source)
        self.assertLess(
            source.index(availability_check),
            source.index("configuration.sharedContainerIdentifier = appGroupName"),
        )

    def test_app_delegate_delegates_startup_and_auth_contexts(self) -> None:
        source = APP_DELEGATE.read_text(encoding="utf-8")

        self.assertIn("ApplicationStartupEnvironment.resolve()", source)
        self.assertIn("self.makeAuthorizedContextSignal()", source)
        self.assertIn("self.makeUnauthorizedContextSignal(buildConfig: buildConfig)", source)
        self.assertIn("self.bindApplicationContexts(launchStartTime: launchStartTime)", source)

    def test_file_system_preparation_is_synchronous_and_throwing(self) -> None:
        source = STARTUP_ENVIRONMENT.read_text(encoding="utf-8")

        self.assertIn("func prepareFileSystem(fileManager: FileManager = .default) throws", source)
        self.assertIn("try performAppGroupUpgradesSynchronously(", source)
        self.assertNotIn("try? fileManager.removeItem(at: testDataUrl)", source)

    def test_startup_has_explicit_states_placeholder_and_timeout(self) -> None:
        state_source = STARTUP_STATE.read_text(encoding="utf-8")
        delegate_source = APP_DELEGATE.read_text(encoding="utf-8")

        for phase in (
            "storagePreparation",
            "accountManager",
            "sharedContext",
            "authorized",
            "unauthorized",
            "ready",
            "failed",
        ):
            self.assertIn(f"case {phase}", state_source)
        self.assertIn("DispatchQueue.main.asyncAfter", state_source)
        self.assertIn("ApplicationStartupPlaceholderController", delegate_source)
        self.assertNotIn("self.mainWindow.viewController = nil", delegate_source)

    def test_external_notification_values_are_not_force_cast(self) -> None:
        delegate_source = APP_DELEGATE.read_text(encoding="utf-8")
        manager_source = SHARED_NOTIFICATION_MANAGER.read_text(encoding="utf-8")

        self.assertNotIn("as! NSString", delegate_source)
        self.assertNotIn("as! NSString", manager_source)
        self.assertIn("notificationInt32Value", delegate_source)
        self.assertIn("notificationManagerInt32Value", manager_source)

    def test_background_task_completion_is_idempotent(self) -> None:
        delegate_source = APP_DELEGATE.read_text(encoding="utf-8")
        wakeup_source = SHARED_WAKEUP_MANAGER.read_text(encoding="utf-8")

        self.assertIn("func endOnce(application: UIApplication)", delegate_source)
        self.assertIn("self.taskId = nil", delegate_source)
        self.assertIn("taskId == actualTaskId", wakeup_source)

    def test_invalid_atomic_state_is_quarantined_without_crashing(self) -> None:
        source = ACCOUNT_MANAGER.read_text(encoding="utf-8")

        self.assertIn("quarantineAccountManagerFile", source)
        self.assertIn('appendingPathComponent("recovery"', source)
        decode_error_section = source.split('postboxLog("decode atomic state error:', 2)[2]
        self.assertIn("self.syncAtomicStateToFile()", decode_error_section)

    def test_sqlite_is_quarantined_before_destructive_recovery(self) -> None:
        source = SQLITE_VALUE_BOX.read_text(encoding="utf-8")

        self.assertIn("private func quarantineSqliteDatabase", source)
        self.assertIn('appendingPathComponent("recovery"', source)
        self.assertIn("guard quarantineSqliteDatabase(databasePath: path) else", source)


if __name__ == "__main__":
    unittest.main()
