import Display

/// Shared weak owner for actions that outlive an individual list-state update.
final class MonogramControllerNavigation {
    weak var controller: ViewController?

    var navigationController: NavigationController? {
        return self.controller?.navigationController as? NavigationController
    }

    func push(_ controller: ViewController) {
        self.controller?.push(controller)
    }

    func present(_ controller: ViewController) {
        self.controller?.present(controller, in: .window(.root))
    }

    func pop() {
        let _ = self.controller?.navigationController?.popViewController(animated: true)
    }
}
