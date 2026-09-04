import Display
import SwiftSignalKit
import TelegramPresentationData
import AccountContext
import ItemListUI
import AlertUI
import PresentationDataUtils

struct MonogramNoteEditorContent {
    let title: String
    let noteHeader: String
    let notePlaceholder: String
    let info: String?
    let openMessageTitle: String?
    let deleteTitle: String?
}

struct MonogramNoteEditorDeletion {
    let title: String
    let text: String
    let action: () -> Signal<Void, NoError>
}

private final class MonogramNoteEditorActions {
    let updateNote: (String) -> Void
    let openMessage: () -> Void
    let delete: () -> Void

    init(updateNote: @escaping (String) -> Void, openMessage: @escaping () -> Void, delete: @escaping () -> Void) {
        self.updateNote = updateNote
        self.openMessage = openMessage
        self.delete = delete
    }
}

private enum MonogramNoteEditorEntry: ItemListNodeEntry {
    case header(String)
    case note(String, String)
    case info(String)
    case openMessage(String)
    case delete(String)

    var section: ItemListSectionId {
        switch self {
        case .header, .note: return 0
        case .info, .openMessage: return 2
        case .delete: return 3
        }
    }

    var stableId: Int32 {
        switch self {
        case .header: return 0
        case .note: return 1
        case .info: return 4
        case .openMessage: return 5
        case .delete: return 6
        }
    }

    static func <(lhs: MonogramNoteEditorEntry, rhs: MonogramNoteEditorEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let actions = arguments as! MonogramNoteEditorActions
        switch self {
        case let .header(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .note(text, placeholder):
            return ItemListMultilineInputItem(
                presentationData: presentationData,
                systemStyle: .glass,
                text: text,
                placeholder: placeholder,
                maxLength: ItemListMultilineInputItemTextLimit(value: 4096, display: true),
                sectionId: self.section,
                style: .blocks,
                capitalization: true,
                autocorrection: true,
                textUpdated: actions.updateNote
            )
        case let .info(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .openMessage(text):
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: text, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: actions.openMessage)
        case let .delete(text):
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: text, kind: .destructive, alignment: .center, sectionId: self.section, style: .blocks, action: actions.delete)
        }
    }
}

private func monogramNoteEditorEntries(note: String, content: MonogramNoteEditorContent) -> [MonogramNoteEditorEntry] {
    var entries: [MonogramNoteEditorEntry] = [.header(content.noteHeader), .note(note, content.notePlaceholder)]
    if let info = content.info {
        entries.append(.info(info))
    }
    if let title = content.openMessageTitle {
        entries.append(.openMessage(title))
    }
    if let title = content.deleteTitle {
        entries.append(.delete(title))
    }
    return entries
}

func monogramNoteEditorController(
    context: AccountContext,
    note: String,
    content: @escaping (PresentationStrings) -> MonogramNoteEditorContent,
    save: @escaping (String) -> Signal<Void, NoError>,
    openMessage: @escaping () -> Void = {},
    deletion: MonogramNoteEditorDeletion?
) -> ViewController {
    let navigation = MonogramControllerNavigation()
    let notePromise = ValuePromise(note, ignoreRepeated: true)
    let actions = MonogramNoteEditorActions(updateNote: { notePromise.set($0) }, openMessage: openMessage, delete: {
        guard let deletion else {
            return
        }
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        navigation.present(textAlertController(
            context: context,
            title: deletion.title,
            text: deletion.text,
            actions: [
                TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {}),
                TextAlertAction(type: .destructiveAction, title: presentationData.strings.Common_Delete, action: {
                    let _ = (deletion.action() |> deliverOnMainQueue).start(completed: { navigation.pop() })
                }),
            ],
            actionLayout: .vertical
        ))
    })
    let signal = combineLatest(context.sharedContext.presentationData, notePromise.get())
    |> deliverOnMainQueue
    |> map { presentationData, note -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let presentationData = presentationData.withUpdated(theme: presentationData.theme.withModalBlocksBackground())
        let content = content(presentationData.strings)
        let done = ItemListNavigationButton(content: .icon(.done), style: .bold, enabled: true, action: {
            let _ = (save(note) |> deliverOnMainQueue).start(completed: { navigation.pop() })
        })
        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text(content.title),
            leftNavigationButton: nil,
            rightNavigationButton: done,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back)
        )
        let listState = ItemListNodeState(
            presentationData: ItemListPresentationData(presentationData),
            entries: monogramNoteEditorEntries(note: note, content: content),
            style: .blocks,
            animateChanges: false
        )
        return (controllerState, (listState, actions))
    }
    let controller = ItemListController(context: context, state: signal)
    navigation.controller = controller
    return controller
}
