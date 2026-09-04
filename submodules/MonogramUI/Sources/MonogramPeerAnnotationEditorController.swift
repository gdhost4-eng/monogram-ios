import Foundation
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import AccountContext
import ItemListUI
import AlertUI
import PresentationDataUtils
import MonogramCore

private struct MonogramPeerAnnotationEditorState: Equatable {
    var note: String
    var tags: String
}

private final class MonogramPeerAnnotationEditorArguments {
    let updateNote: (String) -> Void
    let updateTags: (String) -> Void
    let deleteAnnotation: () -> Void

    init(updateNote: @escaping (String) -> Void, updateTags: @escaping (String) -> Void, deleteAnnotation: @escaping () -> Void) {
        self.updateNote = updateNote
        self.updateTags = updateTags
        self.deleteAnnotation = deleteAnnotation
    }
}

private enum MonogramPeerAnnotationEditorEntry: ItemListNodeEntry {
    case noteHeader(String)
    case note(String, String)
    case tagsHeader(String)
    case tags(String, String)
    case privacyInfo(String)
    case delete(String)

    var section: ItemListSectionId {
        switch self {
        case .noteHeader, .note:
            return 0
        case .tagsHeader, .tags:
            return 1
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
        case .tagsHeader:
            return 2
        case .tags:
            return 3
        case .privacyInfo:
            return 4
        case .delete:
            return 5
        }
    }

    static func ==(lhs: MonogramPeerAnnotationEditorEntry, rhs: MonogramPeerAnnotationEditorEntry) -> Bool {
        switch (lhs, rhs) {
        case let (.noteHeader(lhsText), .noteHeader(rhsText)),
             let (.tagsHeader(lhsText), .tagsHeader(rhsText)),
             let (.privacyInfo(lhsText), .privacyInfo(rhsText)),
             let (.delete(lhsText), .delete(rhsText)):
            return lhsText == rhsText
        case let (.note(lhsText, lhsPlaceholder), .note(rhsText, rhsPlaceholder)),
             let (.tags(lhsText, lhsPlaceholder), .tags(rhsText, rhsPlaceholder)):
            return lhsText == rhsText && lhsPlaceholder == rhsPlaceholder
        default:
            return false
        }
    }

    static func <(lhs: MonogramPeerAnnotationEditorEntry, rhs: MonogramPeerAnnotationEditorEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! MonogramPeerAnnotationEditorArguments
        switch self {
        case let .noteHeader(text), let .tagsHeader(text):
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
        case let .tags(text, placeholder):
            return ItemListSingleLineInputItem(
                presentationData: presentationData,
                systemStyle: .glass,
                title: NSAttributedString(),
                text: text,
                placeholder: placeholder,
                type: .regular(capitalization: false, autocorrection: false),
                returnKeyType: .done,
                clearType: .onFocus,
                maxLength: 512,
                sectionId: self.section,
                textUpdated: arguments.updateTags,
                action: {}
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
    allowsNote: Bool,
    allowsTags: Bool,
    canDelete: Bool
) -> [MonogramPeerAnnotationEditorEntry] {
    var entries: [MonogramPeerAnnotationEditorEntry] = []
    if allowsNote {
        entries.append(.noteHeader(presentationData.strings.Monogram_PeerAnnotation_NoteHeader))
        entries.append(.note(state.note, presentationData.strings.Monogram_PeerAnnotation_NotePlaceholder))
    }
    if allowsTags {
        entries.append(.tagsHeader(presentationData.strings.Monogram_PeerAnnotation_TagsHeader))
        entries.append(.tags(state.tags, presentationData.strings.Monogram_PeerAnnotation_TagsPlaceholder))
    }
    entries.append(.privacyInfo(presentationData.strings.Monogram_PeerAnnotation_PrivacyInfo))
    if canDelete {
        entries.append(.delete(presentationData.strings.Monogram_PeerAnnotation_Delete))
    }
    return entries
}

public func monogramPeerAnnotationEditorController(
    context: AccountContext,
    peerId: PeerId,
    annotation: MonogramPeerAnnotation?,
    allowsNote: Bool,
    allowsTags: Bool
) -> ViewController {
    let initialState = MonogramPeerAnnotationEditorState(
        note: annotation?.note ?? "",
        tags: annotation?.tags.map { "#\($0)" }.joined(separator: " ") ?? ""
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
    }, updateTags: { value in
        updateState { state in
            var state = state
            state.tags = value
            return state
        }
    }, deleteAnnotation: {
        deleteAnnotationImpl?()
    })

    let signal = combineLatest(context.sharedContext.presentationData, statePromise.get())
    |> deliverOnMainQueue
    |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState, Any)) in
        var presentationData = presentationData
        presentationData = presentationData.withUpdated(theme: presentationData.theme.withModalBlocksBackground())

        let rightNavigationButton = ItemListNavigationButton(content: .icon(.done), style: .bold, enabled: allowsNote || allowsTags, action: {
            let note = allowsNote ? state.note : annotation?.note
            let tags = allowsTags ? MonogramTag.parse(state.tags) : annotation?.tags ?? []
            let _ = (setMonogramPeerAnnotation(postbox: context.account.postbox, peerId: peerId, note: note, tags: tags)
            |> deliverOnMainQueue).start(completed: {
                dismissImpl?()
            })
        })
        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text(presentationData.strings.Monogram_PeerAnnotation_Title),
            leftNavigationButton: nil,
            rightNavigationButton: rightNavigationButton,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back)
        )
        let listState = ItemListNodeState(
            presentationData: ItemListPresentationData(presentationData),
            entries: monogramPeerAnnotationEditorEntries(presentationData: presentationData, state: state, allowsNote: allowsNote, allowsTags: allowsTags, canDelete: annotation != nil),
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
            title: presentationData.strings.Monogram_PeerAnnotation_DeleteConfirmTitle,
            text: presentationData.strings.Monogram_PeerAnnotation_DeleteConfirmText,
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
