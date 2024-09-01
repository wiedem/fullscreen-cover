// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "FullScreenCover",
    platforms: [.iOS(.v15)],
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
            ]
        ),
    ]
)
