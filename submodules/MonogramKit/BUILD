load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load("@build_bazel_rules_apple//apple:ios.bzl", "ios_unit_test")
load("@build_bazel_rules_apple//apple/testing/default_runner:ios_test_runner.bzl", "ios_test_runner")

# Monogram: logic that needs nothing but Foundation, kept apart from TelegramCore and the UI
# so that it can be tested on its own (see Package.swift).
swift_library(
    name = "MonogramKit",
    module_name = "MonogramKit",
    srcs = glob([
        "Sources/MonogramKit/**/*.swift",
    ]),
    visibility = [
        "//visibility:public",
    ],
)

swift_library(
    name = "MonogramKitTestsLib",
    testonly = True,
    srcs = glob([
        "Tests/MonogramKitTests/**/*.swift",
    ]),
    deps = [
        ":MonogramKit",
    ],
)

ios_test_runner(
    name = "MonogramKitTestRunner",
    device_type = "iPhone 17",
    os_version = "26.5",
)

ios_unit_test(
    name = "MonogramKitTests",
    minimum_os_version = "13.0",
    runner = ":MonogramKitTestRunner",
    deps = [
        ":MonogramKitTestsLib",
    ],
    visibility = [
        "//visibility:public",
    ],
)
