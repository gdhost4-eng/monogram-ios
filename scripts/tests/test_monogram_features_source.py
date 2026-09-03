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

    def test_ghost_exclusion_is_in_profile_not_message_menu(self):
        menu = self.source("submodules/TelegramUI/Sources/ChatInterfaceStateContextMenus.swift")
        profile = self.source("submodules/TelegramUI/Components/PeerInfo/PeerInfoScreen/Sources/PeerInfoProfileItems.swift")
        self.assertNotIn("Исключить чат из Ghost Mode", menu)
        self.assertIn("Исключить чат из Ghost Mode", profile)
        self.assertIn("settings.ghostModeExcludedPeerIds.removeAll", profile)

    def test_preservation_reads_transaction_settings_not_async_ui_cache(self):
        for filename in ("MonogramEditHistory.swift", "MonogramDeletedMessageTransform.swift"):
            source = self.source("submodules/MonogramCore/Sources/" + filename)
            self.assertIn("monogramAccountSettings(transaction: transaction)", source)
            self.assertNotIn("MonogramRuntimePolicy.isEnabled", source)

    def test_bookmark_uuid_uses_postbox_supported_string_coding(self):
        source = self.source("submodules/MonogramCore/Sources/MonogramBookmark.swift")
        self.assertIn("container.encode(self.id.uuidString, forKey: .id)", source)
        self.assertIn("container.decode(String.self, forKey: .id)", source)

    def test_temporary_account_context_does_not_uninstall_preservation(self):
        source = self.source("submodules/TelegramUI/Sources/AccountContext.swift")
        self.assertRegex(source, r"if !temp \{\s+(?://[^\n]*\n\s*)*self.monogramSettingsDisposable =")
        self.assertRegex(source, r"if let monogramSettingsDisposable = self.monogramSettingsDisposable \{\s+monogramSettingsDisposable.dispose\(\)\s+self.account.postbox.setMessageDeletionTransform\(nil\)")

    def test_preserved_message_ids_are_positive_and_history_uses_navigation(self):
        source = self.source("submodules/MonogramCore/Sources/MonogramDeletedMessageTransform.swift")
        self.assertIn("let localIdValue = max(1, message.id.id)", source)
        menu = self.source("submodules/TelegramUI/Sources/ChatInterfaceStateContextMenus.swift")
        self.assertIn("navigationController()?.pushViewController(monogramEditHistoryController", menu)
        self.assertNotIn("settings.isEnabled(.preserveEditHistory) ? editHistory : nil", menu)


if __name__ == "__main__":
    unittest.main()
