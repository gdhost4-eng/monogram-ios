import unittest
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]

ACCOUNT_LIMIT_FILES = [
    REPOSITORY_ROOT / "submodules" / "AccountUtils" / "Sources" / "AccountUtils.swift",
    REPOSITORY_ROOT / "submodules" / "SettingsUI" / "Sources" / "LogoutOptionsController.swift",
    REPOSITORY_ROOT / "submodules" / "SettingsUI" / "Sources" / "DeleteAccountOptionsController.swift",
    REPOSITORY_ROOT / "submodules" / "SettingsUI" / "Sources" / "Search" / "SettingsSearchableItems.swift",
    REPOSITORY_ROOT / "submodules" / "TelegramUI" / "Components" / "PeerInfo" / "PeerInfoScreen" / "Sources" / "PeerInfoScreenSettingsActions.swift",
]

FORBIDDEN_IDENTIFIERS = [
    "maximumNumberOfAccounts",
    "maximumPremiumNumberOfAccounts",
    "maximumAvailableAccounts",
    "subject: .accounts",
]


class UnlimitedAccountsSourceTests(unittest.TestCase):
    def test_no_fixed_account_limit_gate_remains(self) -> None:
        for path in ACCOUNT_LIMIT_FILES:
            source = path.read_text(encoding="utf-8")
            for identifier in FORBIDDEN_IDENTIFIERS:
                self.assertNotIn(identifier, source, f"{identifier} reintroduced in {path}")

    def test_policy_explicitly_has_no_application_maximum(self) -> None:
        path = REPOSITORY_ROOT / "submodules" / "MonogramCore" / "Sources" / "MonogramAccountPolicy.swift"
        source = path.read_text(encoding="utf-8")
        self.assertIn("applicationAccountLimit: Int? = nil", source)


if __name__ == "__main__":
    unittest.main()

