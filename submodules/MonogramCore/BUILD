load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load("@build_bazel_rules_apple//apple:ios.bzl", "ios_unit_test")
load("@build_bazel_rules_apple//apple/testing/default_runner:ios_test_runner.bzl", "ios_test_runner")

swift_library(
    name = "MonogramCore",
    module_name = "MonogramCore",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/Postbox:Postbox",
        "//submodules/TelegramCore:TelegramCore",
    ],
    visibility = [
        "//visibility:public",
    ],
)

swift_library(
    name = "MonogramCoreTestsLib",
    testonly = True,
    srcs = glob([
        "Tests/**/*.swift",
    ]),
    deps = [
        ":MonogramCore",
        "//submodules/Postbox:Postbox",
        "//submodules/TelegramCore:TelegramCore",
    ],
)

ios_test_runner(
    name = "MonogramCoreTestRunner",
    device_type = "iPhone 17",
    os_version = "26.2",
)

ios_unit_test(
    name = "MonogramCoreTests",
    minimum_os_version = "13.0",
    runner = ":MonogramCoreTestRunner",
    deps = [
        ":MonogramCoreTestsLib",
    ],
    visibility = [
        "//visibility:public",
    ],
)
