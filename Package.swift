// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Kibble",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Kibble",
            path: "Sources/Kibble"
        ),
        .testTarget(
            name: "KibbleTests",
            dependencies: ["Kibble"],
            path: "Tests/KibbleTests"
        ),
    ]
)
