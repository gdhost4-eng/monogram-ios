import Display
import SwiftSignalKit
import TelegramPresentationData
import AccountContext
import MonogramCore

public func monogramBookmarkEditorController(
    context: AccountContext,
    bookmark: MonogramBookmark,
    openMessage: @escaping () -> Void
) -> ViewController {
    return monogramNoteEditorController(
        context: context,
        note: bookmark.note ?? "",
        content: { strings in
            return MonogramNoteEditorContent(
                title: "Локальное закрепление",
                noteHeader: strings.Monogram_BookmarkEditor_NoteHeader,
                notePlaceholder: strings.Monogram_BookmarkEditor_NotePlaceholder,
                info: nil,
                openMessageTitle: strings.Monogram_BookmarkEditor_OpenMessage,
                deleteTitle: "Открепить локально"
            )
        },
        save: { note in
            return setMonogramBookmark(
                postbox: context.account.postbox,
                messageId: bookmark.messageId,
                note: note,
                tags: bookmark.tags + [MonogramBookmark.localPinTag],
                isCopyProtected: false,
                isEphemeral: false
            )
            |> map { _ -> Void in }
        },
        openMessage: openMessage,
        deletion: MonogramNoteEditorDeletion(
            title: "Открепить сообщение?",
            text: "Локальное закрепление будет удалено. Сообщение останется в чате.",
            action: { removeMonogramBookmark(postbox: context.account.postbox, id: bookmark.id) }
        )
    )
}
