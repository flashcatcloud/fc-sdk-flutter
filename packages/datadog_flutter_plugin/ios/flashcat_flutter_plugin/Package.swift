// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "flashcat_flutter_plugin",
    platforms: [
        .iOS("12.0")
    ],
    products: [
        .library(name: "flashcat-flutter-plugin", targets: ["flashcat_flutter_plugin"])
    ],
    dependencies: [
        .package(url: "https://github.com/flashcatcloud/fc-sdk-ios.git", exact: "0.5.0"),
        .package(url: "https://github.com/almazrafi/DictionaryCoder.git", exact: "1.2.0")
    ],
    targets: [
        .systemLibrary(name: "datadog_flutter_plugin_c"),
        .target(
            name: "flashcat_flutter_plugin",
            dependencies: [
                .product(name: "FlashcatCore", package: "fc-sdk-ios"),
                .product(name: "FlashcatLogs-NoOp", package: "fc-sdk-ios"),
                .product(name: "FlashcatCrashReporting", package: "fc-sdk-ios"),
                .product(name: "FlashcatRUM", package: "fc-sdk-ios"),
                "datadog_flutter_plugin_c",
                "DictionaryCoder"
            ],
            resources: []
        )
    ]
)
