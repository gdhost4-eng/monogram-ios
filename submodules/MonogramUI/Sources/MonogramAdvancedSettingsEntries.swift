import Foundation
import Display
import TelegramPresentationData
import ItemListUI
import MonogramCore

private enum MonogramSettingsSection: Int32 {
    case privacy
    case localData
    case chatBehavior
}

enum MonogramAdvancedSettingsEntryId: Hashable {
    case header(ItemListSectionId)
    case toggle(MonogramFeatureId)
    case navigation(MonogramSettingsNavigationAction)
    case footer(ItemListSectionId)
}

struct MonogramAdvancedSettingsEntry: ItemListNodeEntry {
    enum Content: Equatable {
        case header(text: String)
        case toggle(id: MonogramFeatureId, title: String, value: Bool)
        case navigation(title: String, label: String, action: MonogramSettingsNavigationAction)
        case footer(text: String)
    }

    let section: ItemListSectionId
    let index: Int
    let content: Content

    // Identity does not depend on the position or visibility of other rows.
    var stableId: MonogramAdvancedSettingsEntryId {
        switch self.content {
        case .header:
            return .header(self.section)
        case let .toggle(id, _, _):
            return .toggle(id)
        case let .navigation(_, _, action):
            return .navigation(action)
        case .footer:
            return .footer(self.section)
        }
    }

    static func <(lhs: MonogramAdvancedSettingsEntry, rhs: MonogramAdvancedSettingsEntry) -> Bool {
        return lhs.index < rhs.index
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! MonogramAdvancedSettingsControllerArguments
        switch self.content {
        case let .header(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .toggle(id, title, value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: title, value: value, maximumNumberOfLines: 2, sectionId: self.section, style: .blocks, updated: { value in
                arguments.update(id, value)
            })
        case let .navigation(title, label, action):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: title, label: label, sectionId: self.section, style: .blocks, action: {
                switch action {
                case .ghostDuration:
                    arguments.configureGhostDuration()
                case .bookmarks:
                    arguments.openBookmarks()
                case .annotations:
                    arguments.openAnnotations()
                case .clearDeleted:
                    arguments.clearDeleted()
                }
            })
        case let .footer(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

private func monogramFeatureTitle(id: MonogramFeatureId, strings: PresentationStrings) -> String {
    switch id {
    case .advancedSettings:
        return "Monogram"
    case .offlineEntry:
        return "Предупреждение об выходе в сеть"
    case .ghostMode:
        return "Ghost Mode"
    case .ghostReadReceipts:
        return "Не отправлять отметки о прочтении"
    case .ghostTypingActivity:
        return "Скрывать набор текста и запись"
    case .preserveDeletedMessages:
        return "Сохранять удалённые сообщения"
    case .preserveEditHistory:
        return "История редактирования"
    case .localNotes:
        return strings.Monogram_AdvancedSettings_Notes
    case .powerUserInformation:
        return strings.Monogram_AdvancedSettings_PowerUser
    case .localMessagePins:
        return "Локальные закрепления"
    case .confirmVoiceMessages:
        return "Подтверждать голосовые сообщения"
    case .suppressAutomaticKeyboard:
        return "Не открывать клавиатуру автоматически"
    case .suppressIncomingAutoScroll:
        return "Не прокручивать чат при новых сообщениях"
    }
}

func monogramAdvancedSettingsEntries(
    presentationData: PresentationData,
    accountSettings: MonogramSettings,
    timestamp: Int64,
    bookmarksCount: Int,
    annotationsCount: Int,
    deletedCount: Int
) -> [MonogramAdvancedSettingsEntry] {
    var entries: [MonogramAdvancedSettingsEntry] = []
    let ghostModeActive = accountSettings.isGhostModeActive(at: timestamp)

    func append(_ section: MonogramSettingsSection, _ content: MonogramAdvancedSettingsEntry.Content) {
        entries.append(MonogramAdvancedSettingsEntry(section: section.rawValue, index: entries.count, content: content))
    }

    func toggle(_ section: MonogramSettingsSection, _ id: MonogramFeatureId) {
        append(section, .toggle(
            id: id,
            title: monogramFeatureTitle(id: id, strings: presentationData.strings),
            value: id == .ghostMode ? ghostModeActive : accountSettings.isEnabled(id)
        ))
    }

    append(.privacy, .header(text: "ПРИВАТНОСТЬ"))
    toggle(.privacy, .offlineEntry)
    toggle(.privacy, .ghostMode)
    if ghostModeActive {
        let durationLabel: String
        if let expiresAt = accountSettings.ghostModeExpiresAt {
            let remaining = max(0, expiresAt - timestamp)
            durationLabel = remaining >= 3600 ? "\((remaining + 3599) / 3600) ч" : "\((remaining + 59) / 60) мин"
        } else {
            durationLabel = "Постоянно"
        }
        append(.privacy, .navigation(title: "Продолжительность", label: durationLabel, action: .ghostDuration))
        toggle(.privacy, .ghostReadReceipts)
        toggle(.privacy, .ghostTypingActivity)
    }
    append(.privacy, .footer(text: "Предупреждение об выходе в сеть при каждом открытии приложения временно скрывает вашу активность, размывает и блокирует список чатов, если Ghost Mode выключен. Нижняя панель остаётся доступной. Нажмите «Выйти в сеть» для обычной работы или включите Ghost Mode в настройках: список разблокируется автоматически, а активность останется скрытой. Если затем выключить Ghost Mode, предупреждение не появится до следующего входа в приложение. Ghost Mode не меняет серверные настройки «Последняя активность», но при работе приложения не публикует статус «в сети» и не отправляет события прочтения, набора текста и записи из открытого чата."))

    append(.localData, .header(text: "ЛОКАЛЬНЫЕ ДАННЫЕ"))
    toggle(.localData, .preserveDeletedMessages)
    if deletedCount > 0 {
        append(.localData, .navigation(title: "Очистить сохранённые сообщения", label: "\(deletedCount)", action: .clearDeleted))
    }
    toggle(.localData, .preserveEditHistory)
    toggle(.localData, .localMessagePins)
    if accountSettings.isEnabled(.localMessagePins) {
        append(.localData, .navigation(title: "Локальные закрепления", label: "\(bookmarksCount)", action: .bookmarks))
    }
    toggle(.localData, .localNotes)
    if accountSettings.isEnabled(.localNotes) {
        append(.localData, .navigation(title: "Управление заметками", label: "\(annotationsCount)", action: .annotations))
    }
    append(.localData, .footer(text: "Удалённые сообщения остаются на прежнем месте с пометкой. Повторное локальное удаление убирает сохранённую копию. Секретные, исчезающие и защищённые сообщения не сохраняются."))

    append(.chatBehavior, .header(text: "ПОВЕДЕНИЕ ЧАТОВ"))
    toggle(.chatBehavior, .powerUserInformation)
    toggle(.chatBehavior, .confirmVoiceMessages)
    toggle(.chatBehavior, .suppressAutomaticKeyboard)
    toggle(.chatBehavior, .suppressIncomingAutoScroll)
    append(.chatBehavior, .footer(text: "Технические идентификаторы появляются в контекстном меню. Подтверждение записи открывает предпросмотр. Блокировка автопрокрутки сохраняет текущую позицию при входящих сообщениях."))

    return entries
}

