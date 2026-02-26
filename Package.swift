// swift-tools-version: 6.0
import PackageDescription

let commonSwiftSettings: [SwiftSetting] = [
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("InternalImportsByDefault"),
    .enableUpcomingFeature("StrictConcurrency"),
]

let package = Package(
    name: "FullScreenCover",
    platforms: [
        .iOS("16.4"),
    ],
    products: [
        .library(
            name: "FullScreenCover",
            targets: ["FullScreenCover"]
        ),
    ],
    targets: [
        .target(
            name: "FullScreenCover",
            path: "Sources",
            resources: [
                .process("Resources"),
            ],
            swiftSettings: commonSwiftSettings
        ),
        .testTarget(
            name: "FullScreenCoverTests",
            dependencies: ["FullScreenCover"],
            swiftSettings: commonSwiftSettings
        ),
    ],
    swiftLanguageModes: [.v6]
)
