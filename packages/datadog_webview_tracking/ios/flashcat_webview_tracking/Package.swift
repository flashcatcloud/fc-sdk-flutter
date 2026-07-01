// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "flashcat_webview_tracking",
    platforms: [
        .iOS("13.0")
    ],
    products: [
        .library(name: "flashcat-webview-tracking", targets: ["flashcat_webview_tracking"])
    ],
    dependencies: [
        .package(url: "https://github.com/flashcatcloud/fc-sdk-ios.git", exact: "0.5.0")
    ],
    targets: [
        .target(
            name: "flashcat_webview_tracking",
            dependencies: [
                .product(name: "FlashcatCore", package: "fc-sdk-ios"),
                .product(name: "FlashcatWebViewTracking", package: "fc-sdk-ios")
            ],
            resources: []
        )
    ]
)
