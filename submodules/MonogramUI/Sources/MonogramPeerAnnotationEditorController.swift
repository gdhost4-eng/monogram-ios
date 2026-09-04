import Display
import SwiftSignalKit
import Postbox
import AccountContext
import MonogramCore

public func monogramPeerAnnotationEditorController(
    context: AccountContext,
    peerId: PeerId,
    annotation: MonogramPeerAnnotation?
) -> ViewController {
    let deletion: MonogramNoteEditorDeletion?
    if annotation != nil {
        deletion = MonogramNoteEditorDeletion(
            title: "Удалить заметку?",
            text: "Локальная заметка будет удалена с этого устройства.",
            action: { removeMonogramPeerAnnotation(postbox: context.account.postbox, peerId: peerId) }
        )
    } else {
        deletion = nil
    }
    return monogramNoteEditorController(
        context: context,
        note: annotation?.note ?? "",
        content: { _ in
            return MonogramNoteEditorContent(
                title: "Локальная заметка",
                noteHeader: "ЗАМЕТКА",
                notePlaceholder: "Добавить заметку",
                info: "Заметка хранится только на этом устройстве и видна только вам.",
                openMessageTitle: nil,
                deleteTitle: annotation != nil ? "Удалить заметку" : nil
            )
        },
        save: { note in
            return setMonogramPeerAnnotation(
                postbox: context.account.postbox,
                peerId: peerId,
                note: note,
                tags: annotation?.tags ?? []
            )
            |> map { _ -> Void in }
        },
        deletion: deletion
    )
}
