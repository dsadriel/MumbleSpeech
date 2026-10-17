// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MumbleSpeech",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
        .tvOS(.v16),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "MumbleSpeech",
            targets: ["MumbleSpeech"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "MumbleSpeech",
            dependencies: [],
            path: "Sources/MumbleSpeech"
        ),
        .testTarget(
            name: "MumbleSpeechTests",
            dependencies: ["MumbleSpeech"],
            path: "Tests/MumbleSpeechTests"
        ),
    ]
)
