import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext

private final class MonogramSettingsControllerArguments {
    let toggle: (MonogramSettings.Key, Bool) -> Void

    init(toggle: @escaping (MonogramSettings.Key, Bool) -> Void) {
        self.toggle = toggle
    }
}

private enum MonogramSettingsSection: Int32 {
    case ghost
    case messages
    case confirm
    case interface
}

private enum MonogramSettingsEntry: ItemListNodeEntry {
    case header(id: Int32, section: MonogramSettingsSection, text: String)
    case toggle(id: Int32, section: MonogramSettingsSection, key: MonogramSettings.Key, title: String, value: Bool)
    case footer(id: Int32, section: MonogramSettingsSection, text: String)

    var section: ItemListSectionId {
        switch self {
        case let .header(_, section, _), let .toggle(_, section, _, _, _), let .footer(_, section, _):
            return section.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
        case let .header(id, _, _), let .toggle(id, _, _, _, _), let .footer(id, _, _):
            return id
        }
    }

    static func <(lhs: MonogramSettingsEntry, rhs: MonogramSettingsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! MonogramSettingsControllerArguments
        switch self {
        case let .header(_, _, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .toggle(_, _, key, title, value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: title, value: value, maximumNumberOfLines: 2, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggle(key, value)
            })
        case let .footer(_, _, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

private func monogramSettingsEntries() -> [MonogramSettingsEntry] {
    var entries: [MonogramSettingsEntry] = []
    var nextId: Int32 = 0
    func header(_ section: MonogramSettingsSection, _ text: String) {
        entries.append(.header(id: nextId, section: section, text: text))
        nextId += 1
    }
    func toggle(_ section: MonogramSettingsSection, _ key: MonogramSettings.Key, _ title: String) {
        entries.append(.toggle(id: nextId, section: section, key: key, title: title, value: MonogramSettings.get(key)))
        nextId += 1
    }
    func footer(_ section: MonogramSettingsSection, _ text: String) {
        entries.append(.footer(id: nextId, section: section, text: text))
        nextId += 1
    }

    header(.ghost, "РЕЖИМ ПРИЗРАКА")
    toggle(.ghost, .ghostMode, "Режим призрака")
    toggle(.ghost, .ghostNoReadMessages, "Не отправлять «прочитано»")
    toggle(.ghost, .ghostReadOnSend, "Отправлять «прочитано» при ответе")
    toggle(.ghost, .ghostNoOnline, "Скрывать онлайн")
    toggle(.ghost, .ghostNoTyping, "Скрывать «печатает…»")
    toggle(.ghost, .ghostNoOtherActions, "Скрывать запись голосовых, выбор стикеров и отправку файлов")
    toggle(.ghost, .ghostNoStoryViews, "Не отмечать истории просмотренными")
    footer(.ghost, "Пункты работают, пока включён режим призрака. Чат читается только у вас; «Прочитать (видно собеседнику)» в меню чата в списке отправляет отметку по-настоящему. Войти в режим, не засветившись онлайн, можно долгим нажатием на иконку Monogram.")

    header(.messages, "СООБЩЕНИЯ И МЕДИА")
    toggle(.messages, .saveDeletedMessages, "Сохранять удалённые сообщения")
    toggle(.messages, .saveEditHistory, "Сохранять историю изменений")
    toggle(.messages, .saveSelfDestructingMedia, "Сохранять одноразовые медиа")
    toggle(.messages, .bypassCopyProtection, "Снимать запрет на копирование")
    footer(.messages, "Удалённые сообщения остаются в чате с пометкой 🗑. История изменений открывается из меню сообщения. Одноразовые фото и видео и медиа с таймером остаются в чате после просмотра. В защищённых чатах можно копировать текст и сохранять медиа, а пересылка отправляет копию сообщения.")

    header(.confirm, "СПРАШИВАТЬ ПЕРЕД ОТПРАВКОЙ")
    toggle(.confirm, .confirmStickers, "Стикеров")
    toggle(.confirm, .confirmGifs, "GIF")
    toggle(.confirm, .confirmVoice, "Голосовых и кружков")

    header(.interface, "ИНТЕРФЕЙС")
    toggle(.interface, .hideSponsored, "Скрывать рекламу")
    toggle(.interface, .showPeerIds, "Показывать ID и дату регистрации")
    toggle(.interface, .localNotes, "Личные заметки в профилях")
    toggle(.interface, .hideStories, "Скрывать истории в списке чатов")
    footer(.interface, "Заметки видны только вам и хранятся на этом устройстве.")

    return entries
}

public func monogramSettingsController(context: AccountContext) -> ViewController {
    let arguments = MonogramSettingsControllerArguments(toggle: { key, value in
        MonogramSettings.set(key, value)
    })

    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        MonogramSettings.updates()
    )
    |> map { presentationData, _ -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text("Monogram"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: monogramSettingsEntries(), style: .blocks, animateChanges: false)
        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    return controller
}
