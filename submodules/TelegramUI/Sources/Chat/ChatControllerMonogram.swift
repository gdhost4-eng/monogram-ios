import Foundation
import UIKit
import Display
import TelegramCore
import AccountContext
import PresentationDataUtils

extension ChatControllerImpl {
    /// Monogram: asks before a send that is easy to do by accident (stickers, GIFs).
    /// Returns true when the send was intercepted; `send` repeats it after the confirmation.
    func monogramConfirmSendIfNeeded(_ key: MonogramSettings.Key, text: String, send: @escaping () -> Void) -> Bool {
        if self.monogramSendConfirmed || !MonogramSettings.get(key) {
            return false
        }
        self.present(textAlertController(context: self.context, updatedPresentationData: self.updatedPresentationData, title: nil, text: text, actions: [
            TextAlertAction(type: .genericAction, title: self.presentationData.strings.Common_Cancel, action: {}),
            TextAlertAction(type: .defaultAction, title: "Отправить", action: { [weak self] in
                guard let self else {
                    return
                }
                self.monogramSendConfirmed = true
                send()
                self.monogramSendConfirmed = false
            })
        ]), in: .window(.root))
        return true
    }
}
