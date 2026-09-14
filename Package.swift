// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "XrayClient",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        // Protocol and validation shared by the app and the privileged helper.
        // Kept tiny on purpose: it is the only code that exists on both sides
        // of the privilege boundary.
        .target(
            name: "VeilHelperKit",
            path: "Sources/VeilHelperKit"
        ),
        // The privileged helper itself — a launchd daemon that runs as root and
        // accepts a fixed set of typed commands from the app.
        .executableTarget(
            name: "VeilHelper",
            dependencies: ["VeilHelperKit"],
            path: "Sources/VeilHelper"
        ),
        .executableTarget(
            name: "XrayClient",
            dependencies: ["VeilHelperKit"],
            path: "Sources/XrayClient",
            resources: [
                .copy("Resources/xray"),
                .copy("Resources/xray.sha256"),
                .copy("Resources/sing-box"),
                .copy("Resources/sing-box.sha256")
            ]
        ),
        .testTarget(
            name: "XrayClientTests",
            dependencies: ["XrayClient", "VeilHelperKit"],
            path: "Tests/XrayClientTests"
        )
    ]
)
