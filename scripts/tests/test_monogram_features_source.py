from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]


class MonogramFeaturesSourceTests(unittest.TestCase):
    def source(self, relative: str) -> str:
        return (ROOT / relative).read_text(encoding="utf-8")

    def test_settings_screen_contains_no_removed_placeholder_features(self):
        registry = self.source("submodules/MonogramCore/Sources/MonogramFeatureRegistry.swift")
        for removed in (
            "appearanceEnhancements",
            "searchEnhancements",
            "translationControls",
            "mediaEnhancements",
            "storageEnhancements",
            "developerTools",
        ):
            self.assertNotIn(removed, registry)

    def test_ghost_mode_gates_read_and_activity_paths(self):
        account_context = self.source("submodules/TelegramUI/Sources/AccountContext.swift")
        chat_controller = self.source("submodules/TelegramUI/Sources/ChatController.swift")
        wakeup_manager = self.source("submodules/TelegramUI/Sources/SharedWakeupManager.swift")
        self.assertIn("suppressesReadReceipts", account_context)
        self.assertGreaterEqual(chat_controller.count("suppressesInputActivity"), 3)
        self.assertIn("suppressOnlinePresence", wakeup_manager)
        self.assertIn("!tasks.suppressOnlinePresence", wakeup_manager)
        self.assertIn("mapToSignal", wakeup_manager)
        self.assertIn("delay(Double(remaining)", wakeup_manager)

    def test_deleted_messages_use_isolated_namespace_and_sensitive_guards(self):
        transform = self.source("submodules/MonogramCore/Sources/MonogramDeletedMessageTransform.swift")
        namespaces = self.source("submodules/TelegramCore/Sources/SyncCore/SyncCore_Namespaces.swift")
        self.assertIn("MonogramLocal", namespaces)
        self.assertIn("Namespaces.Message.MonogramLocal", transform)
        self.assertIn("Namespaces.Peer.SecretChat", transform)
        self.assertIn("CopyProtected", transform)
        self.assertIn("AutoremoveTimeoutMessageAttribute", transform)

    def test_edit_history_is_bounded_and_sensitive_content_is_rejected(self):
        history = self.source("submodules/MonogramCore/Sources/MonogramEditHistory.swift")
        self.assertIn("history.revisions.count > 50", history)
        self.assertIn("Namespaces.Peer.SecretChat", history)
        self.assertIn("CopyProtected", history)

    def test_chat_actions_expose_history_pins_and_manual_read(self):
        menu = self.source("submodules/TelegramUI/Sources/ChatInterfaceStateContextMenus.swift")
        self.assertIn('text: "Изменения', menu)
        self.assertIn("Текущая версия", menu)
        self.assertIn("monogramEditHistoryEntries", menu)
        self.assertIn("Закрепить локально", menu)
        self.assertIn("Отметить прочитанным сейчас", menu)
        self.assertIn("Удалить локальную копию", menu)

    def test_incoming_auto_scroll_can_preserve_the_viewport(self):
        history = self.source("submodules/TelegramUI/Sources/ChatHistoryListNode.swift")
        registry = self.source("submodules/MonogramCore/Sources/MonogramFeatureRegistry.swift")
        self.assertIn("suppressIncomingAutoScroll", registry)
        self.assertIn("message.flags.contains(.Incoming)", history)
        self.assertIn("rawTransition.stationaryItemRange = (0, Int.max)", history)


if __name__ == "__main__":
    unittest.main()
