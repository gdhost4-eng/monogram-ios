import re
import unittest
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
CORE_SOURCES = REPOSITORY_ROOT / "submodules" / "MonogramCore" / "Sources"


class LocalDataSourceTests(unittest.TestCase):
    def test_custom_ordered_list_collection_ids_are_unique(self) -> None:
        identifiers: list[int] = []
        pattern = re.compile(r"CollectionId: Int32 = (0x[0-9a-fA-F]+)")
        for path in CORE_SOURCES.glob("*Repository.swift"):
            identifiers.extend(int(value, 16) for value in pattern.findall(path.read_text(encoding="utf-8")))

        self.assertGreaterEqual(len(identifiers), 2)
        self.assertEqual(len(identifiers), len(set(identifiers)))
        self.assertTrue(all(identifier >= 0x4D000000 for identifier in identifiers))

    def test_bookmark_model_keeps_reference_not_message_payload(self) -> None:
        source = (CORE_SOURCES / "MonogramBookmark.swift").read_text(encoding="utf-8")
        self.assertIn("public let messageId: MessageId", source)
        self.assertNotIn("public let messageText", source)
        self.assertNotIn("public let media", source)

    def test_sensitive_message_policy_is_mandatory_for_writes(self) -> None:
        policy = (CORE_SOURCES / "MonogramLocalDataPolicy.swift").read_text(encoding="utf-8")
        repository = (CORE_SOURCES / "MonogramBookmarksRepository.swift").read_text(encoding="utf-8")

        self.assertIn("Namespaces.Peer.SecretChat", policy)
        self.assertIn("Namespaces.Message.allEphemeral", policy)
        self.assertIn("isCopyProtected", policy)
        self.assertIn("MonogramLocalDataPolicy.bookmarkDenialReason", repository)
        self.assertRegex(repository, r"isCopyProtected: Bool,\s+isEphemeral: Bool,")

    def test_message_context_action_is_feature_and_privacy_gated(self) -> None:
        source = (
            REPOSITORY_ROOT
            / "submodules"
            / "TelegramUI"
            / "Sources"
            / "ChatInterfaceStateContextMenus.swift"
        ).read_text(encoding="utf-8")

        self.assertIn("settings.isEnabled(.localMessagePins)", source)
        self.assertIn("MonogramLocalDataPolicy.bookmarkDenialReason", source)
        self.assertIn("setMonogramBookmark(", source)
        self.assertIn("removeMonogramBookmark(", source)

    def test_bookmarks_list_is_account_scoped_and_navigable(self) -> None:
        controller = (CORE_SOURCES.parent.parent / "MonogramUI" / "Sources" / "MonogramBookmarksController.swift").read_text(encoding="utf-8")
        editor = (CORE_SOURCES.parent.parent / "MonogramUI" / "Sources" / "MonogramBookmarkEditorController.swift").read_text(encoding="utf-8")
        advanced_settings = (CORE_SOURCES.parent.parent / "MonogramUI" / "Sources" / "MonogramAdvancedSettingsController.swift").read_text(encoding="utf-8")

        self.assertIn("searchMonogramBookmarks(postbox: context.account.postbox", controller)
        self.assertIn("queryPromise", controller)
        self.assertIn("arguments.editBookmark(value)", controller)
        self.assertIn("monogramBookmarkEditorController", controller)
        self.assertIn('tags: ["monogram-pin"]', editor)
        self.assertIn("removeMonogramBookmark", editor)
        self.assertIn("openMessage: openMessage", editor)
        self.assertIn("Открепить сообщение?", editor)
        self.assertIn("TextAlertAction(type: .destructiveAction", editor)
        self.assertIn("monogramBookmarksController(context: context", advanced_settings)
        self.assertIn("navigateToChatController", advanced_settings)


if __name__ == "__main__":
    unittest.main()
