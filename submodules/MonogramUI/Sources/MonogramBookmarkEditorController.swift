import Foundation
import Display
import SwiftSignalKit
import TelegramPresentationData
import AccountContext
import ItemListUI
import AlertUI
import PresentationDataUtils
import MonogramCore

private struct MonogramBookmarkEditorState: Equatable {
    var note: String
}

private final class MonogramBookmarkEditorArguments {
    let updateNote: (String) -> Void
    let openMessage: () -> Void
    let deleteBookmark: () -> Void

    init(
        updateNote: @escaping (String) -> Void,
        openMessage: @escaping () -> Void,
        deleteBookmark: @escaping () -> Void
    ) {
        self.updateNote = updateNote
        self.openMessage = openMessage
        self.deleteBookmark = deleteBookmark
    }
}

private enum MonogramBookmarkEditorEntry: ItemListNodeEntry {
    case noteHeader(String)
    case note(String, String)
    case openMessage(String)
    case delete(String)

    var section: ItemListSectionId {
        switch self {
        case .noteHeader, .note:
            return 0
        case .openMessage:
            return 2
        case .delete:
            return 3
        }
    }

    var stableId: Int32 {
        switch self {
        case .noteHeader:
            return 0
        case .note:
            return 1
        case .openMessage:
            return 5
        case .delete:
            return 6
        }
    }

    static func <(lhs: MonogramBookmarkEditorEntry, rhs: MonogramBookmarkEditorEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! MonogramBookmarkEditorArguments
        switch self {
        case let .noteHeader(text):
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
                textUpdated: arguments.updateNote
            )
        case let .openMessage(text):
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: text, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: arguments.openMessage)
        case let .delete(text):
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: text, kind: .destructive, alignment: .center, sectionId: self.section, style: .blocks, action: arguments.deleteBookmark)
        }
    }
}

private func monogramBookmarkEditorEntries(
    presentationData: PresentationData,
    state: MonogramBookmarkEditorState
) -> [MonogramBookmarkEditorEntry] {
    return [
        .noteHeader(presentationData.strings.Monogram_BookmarkEditor_NoteHeader),
        .note(state.note, presentationData.strings.Monogram_BookmarkEditor_NotePlaceholder),
        .openMessage(presentationData.strings.Monogram_BookmarkEditor_OpenMessage),
        .delete("Открепить локально"),
    ]
}

public func monogramBookmarkEditorController(
    context: AccountContext,
    bookmark: MonogramBookmark,
    openMessage: @escaping () -> Void
) -> ViewController {
    let initialState = MonogramBookmarkEditorState(
        note: bookmark.note ?? ""
    )
    let stateValue = Atomic(value: initialState)
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let updateState: ((MonogramBookmarkEditorState) -> MonogramBookmarkEditorState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }

    var dismissImpl: (() -> Void)?
    var deleteBookmarkImpl: (() -> Void)?
    let arguments = MonogramBookmarkEditorArguments(
        updateNote: { value in
            updateState { state in
                var state = state
                state.note = value
                return state
            }
        },
        openMessage: openMessage,
        deleteBookmark: {
            deleteBookmarkImpl?()
        }
    )

    let signal = combineLatest(context.sharedContext.presentationData, statePromise.get())
    |> deliverOnMainQueue
    |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let presentationData = presentationData.withUpdated(theme: presentationData.theme.withModalBlocksBackground())

        let rightNavigationButton = ItemListNavigationButton(content: .icon(.done), style: .bold, enabled: true, action: {
            let _ = (setMonogramBookmark(
                postbox: context.account.postbox,
                messageId: bookmark.messageId,
                note: state.note,
                tags: ["monogram-pin"],
                isCopyProtected: false,
                isEphemeral: false
            )
            |> deliverOnMainQueue).start(completed: {
                dismissImpl?()
            })
        })
        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text("Локальное закрепление"),
            leftNavigationButton: nil,
            rightNavigationButton: rightNavigationButton,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back)
        )
        let listState = ItemListNodeState(
            presentationData: ItemListPresentationData(presentationData),
            entries: monogramBookmarkEditorEntries(presentationData: presentationData, state: state),
            style: .blocks,
            animateChanges: false
        )
        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    dismissImpl = { [weak controller] in
        let _ = controller?.navigationController?.popViewController(animated: true)
    }
    deleteBookmarkImpl = { [weak controller] in
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        controller?.present(textAlertController(
            context: context,
            title: "Открепить сообщение?",
            text: "Локальное закрепление будет удалено. Сообщение останется в чате.",
            actions: [
                TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {}),
                TextAlertAction(type: .destructiveAction, title: presentationData.strings.Common_Delete, action: {
                    let _ = (removeMonogramBookmark(postbox: context.account.postbox, id: bookmark.id)
                    |> deliverOnMainQueue).start(completed: {
                        dismissImpl?()
                    })
                }),
            ],
            actionLayout: .vertical
        ), in: .window(.root))
    }
    return controller
}
