import Foundation
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import AccountContext
import ItemListUI
import AlertUI
import PresentationDataUtils
import MonogramCore

private struct MonogramPeerAnnotationEditorState: Equatable {
    var note: String
}

private final class MonogramPeerAnnotationEditorArguments {
    let updateNote: (String) -> Void
    let deleteAnnotation: () -> Void

    init(updateNote: @escaping (String) -> Void, deleteAnnotation: @escaping () -> Void) {
        self.updateNote = updateNote
        self.deleteAnnotation = deleteAnnotation
    }
}

private enum MonogramPeerAnnotationEditorEntry: ItemListNodeEntry {
    case noteHeader(String)
    case note(String, String)
    case privacyInfo(String)
    case delete(String)

    var section: ItemListSectionId {
        switch self {
        case .noteHeader, .note:
            return 0
        case .privacyInfo:
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
        case .privacyInfo:
            return 4
        case .delete:
            return 5
        }
    }

    static func <(lhs: MonogramPeerAnnotationEditorEntry, rhs: MonogramPeerAnnotationEditorEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! MonogramPeerAnnotationEditorArguments
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
        case let .privacyInfo(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .delete(text):
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: text, kind: .destructive, alignment: .center, sectionId: self.section, style: .blocks, action: arguments.deleteAnnotation)
        }
    }
}

private func monogramPeerAnnotationEditorEntries(
    presentationData: PresentationData,
    state: MonogramPeerAnnotationEditorState,
    canDelete: Bool
) -> [MonogramPeerAnnotationEditorEntry] {
    var entries: [MonogramPeerAnnotationEditorEntry] = []
    entries.append(.noteHeader("ЗАМЕТКА"))
    entries.append(.note(state.note, "Добавить заметку"))
    entries.append(.privacyInfo("Заметка хранится только на этом устройстве и видна только вам."))
    if canDelete {
        entries.append(.delete("Удалить заметку"))
    }
    return entries
}

public func monogramPeerAnnotationEditorController(
    context: AccountContext,
    peerId: PeerId,
    annotation: MonogramPeerAnnotation?
) -> ViewController {
    let initialState = MonogramPeerAnnotationEditorState(
        note: annotation?.note ?? ""
    )
    let stateValue = Atomic(value: initialState)
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let updateState: ((MonogramPeerAnnotationEditorState) -> MonogramPeerAnnotationEditorState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }

    var dismissImpl: (() -> Void)?
    var deleteAnnotationImpl: (() -> Void)?
    let arguments = MonogramPeerAnnotationEditorArguments(updateNote: { value in
        updateState { state in
            var state = state
            state.note = value
            return state
        }
    }, deleteAnnotation: {
        deleteAnnotationImpl?()
    })

    let signal = combineLatest(context.sharedContext.presentationData, statePromise.get())
    |> deliverOnMainQueue
    |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let presentationData = presentationData.withUpdated(theme: presentationData.theme.withModalBlocksBackground())

        let rightNavigationButton = ItemListNavigationButton(content: .icon(.done), style: .bold, enabled: true, action: {
            let note = state.note
            let tags: [String] = []
            let _ = (setMonogramPeerAnnotation(postbox: context.account.postbox, peerId: peerId, note: note, tags: tags)
            |> deliverOnMainQueue).start(completed: {
                dismissImpl?()
            })
        })
        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text("Локальная заметка"),
            leftNavigationButton: nil,
            rightNavigationButton: rightNavigationButton,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back)
        )
        let listState = ItemListNodeState(
            presentationData: ItemListPresentationData(presentationData),
            entries: monogramPeerAnnotationEditorEntries(presentationData: presentationData, state: state, canDelete: annotation != nil),
            style: .blocks,
            animateChanges: false
        )
        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    dismissImpl = { [weak controller] in
        let _ = controller?.navigationController?.popViewController(animated: true)
    }
    deleteAnnotationImpl = { [weak controller] in
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        controller?.present(textAlertController(
            context: context,
            title: "Удалить заметку?",
            text: "Локальная заметка будет удалена с этого устройства.",
            actions: [
                TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {}),
                TextAlertAction(type: .destructiveAction, title: presentationData.strings.Common_Delete, action: {
                    let _ = (removeMonogramPeerAnnotation(postbox: context.account.postbox, peerId: peerId)
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
