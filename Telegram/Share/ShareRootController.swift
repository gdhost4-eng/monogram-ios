import UIKit
import TelegramUI
import BuildConfig
import ShareExtensionContext
import SwiftSignalKit
import TelegramCore

@objc(ShareRootController)
class ShareRootController: UIViewController {
    private var impl: ShareRootControllerImpl?

    @objc private func closeUnavailableExtension() {
        self.extensionContext?.cancelRequest(
            withError: NSError(
                domain: "Monogram.ShareExtension",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Shared application container is unavailable."]
            )
        )
    }

    private func showUnavailableState() {
        if #available(iOS 13.0, *) {
            self.view.backgroundColor = .systemBackground
        } else {
            self.view.backgroundColor = .white
        }
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.textAlignment = .center
        label.text = "Sharing is unavailable because the shared application container is not configured."
        self.view.addSubview(label)
        let closeButton = UIButton(type: .system)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.setTitle("Close", for: .normal)
        closeButton.addTarget(self, action: #selector(self.closeUnavailableExtension), for: .touchUpInside)
        self.view.addSubview(closeButton)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: self.view.centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: self.view.leadingAnchor, constant: 24.0),
            label.trailingAnchor.constraint(lessThanOrEqualTo: self.view.trailingAnchor, constant: -24.0),
            closeButton.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            closeButton.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 20.0)
        ])
    }
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        
        self.modalPresentationStyle = .fullScreen
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        super.loadView()
        
        if self.impl == nil {
            guard let appBundleIdentifier = Bundle.main.bundleIdentifier,
                  let lastDotRange = appBundleIdentifier.range(of: ".", options: [.backwards]) else {
                self.showUnavailableState()
                return
            }
            
            let baseAppBundleId = String(appBundleIdentifier[..<lastDotRange.lowerBound])
            
            let buildConfig = BuildConfig(baseAppBundleId: baseAppBundleId)
            
            let languagesCategory = "ios"
            
            let appGroupName = "group.\(baseAppBundleId)"
            let maybeAppGroupUrl = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupName)
            
            guard let appGroupUrl = maybeAppGroupUrl else {
                self.showUnavailableState()
                return
            }
            
            let rootPath = appGroupUrl.path + "/telegram-data"
            
            let deviceSpecificEncryptionParameters = BuildConfig.deviceSpecificEncryptionParameters(rootPath, baseAppBundleId: baseAppBundleId)
            let encryptionParameters: (Data, Data) = (deviceSpecificEncryptionParameters.key, deviceSpecificEncryptionParameters.salt)
            
            let appVersion = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "unknown"
            
            self.impl = ShareRootControllerImpl(initializationData: ShareRootControllerInitializationData(appBundleId: baseAppBundleId, appBuildType: buildConfig.isAppStoreBuild ? .public : .internal, appGroupPath: appGroupUrl.path, apiId: buildConfig.apiId, apiHash: buildConfig.apiHash, languagesCategory: languagesCategory, encryptionParameters: encryptionParameters, appVersion: appVersion, bundleData: buildConfig.bundleData(withAppToken: nil, tokenType: nil, tokenEnvironment: nil, signatureDict: nil), useBetaFeatures: !buildConfig.isAppStoreBuild, makeTempContext: { accountManager, appLockContext, applicationBindings, InitialPresentationDataAndSettings, networkArguments in
                return makeTempContext(
                    sharedContainerPath: appGroupUrl.path,
                    rootPath: rootPath,
                    appGroupPath: appGroupUrl.path,
                    accountManager: accountManager,
                    appLockContext: appLockContext,
                    encryptionParameters: EngineValueBoxEncryptionParameters(
                        forceEncryptionIfNoSet: false,
                        key: EngineValueBoxEncryptionParameters.Key(data: encryptionParameters.0)!,
                        salt: EngineValueBoxEncryptionParameters.Salt(data: encryptionParameters.1)!
                    ),
                    applicationBindings: applicationBindings,
                    initialPresentationDataAndSettings: InitialPresentationDataAndSettings,
                    networkArguments: networkArguments,
                    buildConfig: buildConfig
                )
            }), getExtensionContext: { [weak self] in
                return self?.extensionContext
            })
            
            self.impl?.openUrl = { [weak self] url in
                guard let self, let url = URL(string: url) else {
                    return
                }
                let _ = self.openURL(url)
            }
        }
        
        self.impl?.loadView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.impl?.viewWillAppear()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.impl?.viewWillDisappear()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        self.impl?.viewWillDisappear()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.impl?.viewDidLayoutSubviews(view: self.view, traitCollection: self.traitCollection)
    }
    
    @objc func openURL(_ url: URL) -> Bool {
        var responder: UIResponder? = self
        while responder != nil {
            if let application = responder as? UIApplication {
                if #available(iOS 18.0, *) {
                    application.open(url, options: [:], completionHandler: nil)
                    return true
                } else {
                    return application.perform(#selector(openURL(_:)), with: url) != nil
                }
            }
            responder = responder?.next
        }
        return false
    }
}
