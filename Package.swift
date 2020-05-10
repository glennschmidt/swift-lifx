// swift-tools-version:5.2

import PackageDescription

let package = Package(
    name: "Lifx",
    platforms: [
        .iOS(SupportedPlatform.IOSVersion.v13),
        .macOS(SupportedPlatform.MacOSVersion.v10_15),
        .tvOS(SupportedPlatform.TVOSVersion.v13),
        .watchOS(SupportedPlatform.WatchOSVersion.v6),
    ],
    products: [
        .library(
            name: "Lifx",
            targets: ["Lifx"]),
    ],
    targets: [
        .target(
            name: "Lifx",
            dependencies: []),
        .testTarget(
            name: "LifxTests",
            dependencies: ["Lifx"]),
    ]
)
