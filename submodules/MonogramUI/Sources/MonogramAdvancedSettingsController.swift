import Display
import SwiftSignalKit
import TelegramPresentationData
import AccountContext
import ItemListUI
import PresentationDataUtils

public func monogramAdvancedSettingsController(context: AccountContext) -> ViewController {
    let actions = MonogramAdvancedSettingsActions(context: context)
    let signal = combineLatest(
        context.sharedContext.presentationData,
        monogramAdvancedSettingsState(context: context)
    )
    |> deliverOnMainQueue
    |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let presentationData = presentationData.withUpdated(theme: presentationData.theme.withModalBlocksBackground())
        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text("Monogram"),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back)
        )
        let listState = ItemListNodeState(
            presentationData: ItemListPresentationData(presentationData),
            entries: monogramAdvancedSettingsEntries(presentationData: presentationData, state: state),
            style: .blocks,
            animateChanges: true
        )
        return (controllerState, (listState, actions))
    }

    let controller = ItemListController(context: context, state: signal)
    controller.navigationPresentation = .modal
    actions.navigation.controller = controller
    return controller
}
