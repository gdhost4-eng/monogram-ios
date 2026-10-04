// swift-tools-version: 5.9
import PackageDescription

// The app is built with Bazel (see BUILD). This manifest exists so that the tests of the pure logic
// run with a plain `swift test`, without a simulator and without building the rest of the app.
let package = Package(
    name: "MonogramKit",
    platforms: [.iOS(.v13), .macOS(.v10_13)],
    products: [
        .library(name: "MonogramKit", targets: ["MonogramKit"]),
    ],
    targets: [
        .target(name: "MonogramKit"),
        .testTarget(name: "MonogramKitTests", dependencies: ["MonogramKit"]),
    ]
)
