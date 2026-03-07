// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ClaudeToolbar",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "ClaudeToolbar",
            path: "Sources/ClaudeToolbar",
            swiftSettings: [
                .unsafeFlags(["-strict-concurrency=complete"])
            ]
        )
    ]
)
