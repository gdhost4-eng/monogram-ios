import Foundation
import UIKit
import AsyncDisplayKit
import Display

enum ApplicationStartupPhase: String {
    case storagePreparation
    case accountManager
    case sharedContext
    case authorized
    case unauthorized
    case ready
    case failed

    var isTerminal: Bool {
        switch self {
        case .ready, .failed:
            return true
        default:
            return false
        }
    }
}

final class ApplicationStartupStateMachine {
    private(set) var phase: ApplicationStartupPhase?
    private var generation: Int = 0
    private let timeout: TimeInterval
    private let timedOut: (ApplicationStartupPhase) -> Void

    init(timeout: TimeInterval = 30.0, timedOut: @escaping (ApplicationStartupPhase) -> Void) {
        self.timeout = timeout
        self.timedOut = timedOut
    }

    func transition(to phase: ApplicationStartupPhase) {
        if self.phase == .failed {
            return
        }
        self.phase = phase
        self.generation += 1
        let generation = self.generation
        NSLog("Application startup phase: %@", phase.rawValue)

        guard !phase.isTerminal else {
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + self.timeout) { [weak self] in
            guard let self, self.generation == generation, self.phase == phase else {
                return
            }
            self.phase = .failed
            self.generation += 1
            NSLog("Application startup phase timed out: %@", phase.rawValue)
            self.timedOut(phase)
        }
    }
}

final class ApplicationStartupPlaceholderController: ViewController {
    private let message: String
    private let showsActivity: Bool

    init(message: String, showsActivity: Bool) {
        self.message = message
        self.showsActivity = showsActivity
        super.init(navigationBarPresentationData: nil)
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadDisplayNode() {
        let node = ASDisplayNode()
        if #available(iOS 13.0, *) {
            node.backgroundColor = .systemBackground
        } else {
            node.backgroundColor = .white
        }

        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.textAlignment = .center
        label.text = self.message
        if #available(iOS 13.0, *) {
            label.textColor = .label
        } else {
            label.textColor = .black
        }
        node.view.addSubview(label)

        var constraints: [NSLayoutConstraint] = [
            label.centerXAnchor.constraint(equalTo: node.view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: node.view.centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: node.view.leadingAnchor, constant: 32.0),
            label.trailingAnchor.constraint(lessThanOrEqualTo: node.view.trailingAnchor, constant: -32.0)
        ]
        if self.showsActivity {
            let indicator: UIActivityIndicatorView
            if #available(iOS 13.0, *) {
                indicator = UIActivityIndicatorView(style: .medium)
            } else {
                indicator = UIActivityIndicatorView(style: .gray)
            }
            indicator.translatesAutoresizingMaskIntoConstraints = false
            indicator.startAnimating()
            node.view.addSubview(indicator)
            constraints.append(indicator.centerXAnchor.constraint(equalTo: node.view.centerXAnchor))
            constraints.append(indicator.bottomAnchor.constraint(equalTo: label.topAnchor, constant: -16.0))
        }
        NSLayoutConstraint.activate(constraints)
        self.displayNode = node
        self.displayNodeDidLoad()
    }
}
