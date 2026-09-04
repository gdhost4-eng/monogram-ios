from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


class GhostLocalReadTests(unittest.TestCase):
    def source(self, path):
        return (ROOT / path).read_text(encoding="utf-8")

    def test_local_read_updates_state_before_skipping_server_queue(self):
        source = self.source("submodules/Postbox/Sources/MessageHistoryTable.swift")
        method = source.split("func applyInteractiveMaxReadIndex(", 1)[1].split("return messageIds", 2)
        self.assertIn(".UpdateReadState", method[0])
        self.assertIn("guard !locally else", method[0])
        self.assertIn("synchronizeReadStateTable.set", method[1])

    def test_local_flag_reaches_associated_chats_and_namespaces(self):
        source = self.source("submodules/Postbox/Sources/Postbox.swift")
        method = source.split("fileprivate func applyInteractiveReadMaxIndex(", 1)[1].split("func applyMarkUnread", 1)[0]
        self.assertEqual(method.count("locally: locally"), 3)

    def test_threads_skip_receipts_after_updating_local_unread_count(self):
        source = self.source("submodules/TelegramCore/Sources/TelegramEngine/Messages/ReplyThreadHistory.swift")
        count = source.index("strongSelf.unreadCountValue = unreadCountValue")
        stop = source.index("if locally {", count)
        receipt = source.index("Api.functions.messages.readSavedHistory", count)
        self.assertLess(count, stop)
        self.assertLess(stop, receipt)
        self.assertIn("return", source[stop:receipt])
        self.assertIn("index: messageIndex, locally: locally", source)

    def test_local_reads_require_ghost_read_receipts_setting(self):
        source = self.source("submodules/MonogramCore/Sources/MonogramRuntimePolicy.swift")
        policy = source.split("func readsHistoryLocally", 1)[1].split("public static func", 1)[0]
        self.assertIn("activeGhostSettings", policy)
        self.assertIn("isEnabled(.ghostReadReceipts)", policy)
        context = self.source("submodules/TelegramUI/Sources/AccountContext.swift")
        self.assertIn("locally && !MonogramRuntimePolicy.readsHistoryLocally", context)
        self.assertIn("applyMaxReadIndexInteractively(index: messageIndex, locally: locally)", context)
        self.assertIn("context.applyMaxReadIndex(messageIndex: messageIndex, locally: locally)", context)


if __name__ == "__main__":
    unittest.main()
