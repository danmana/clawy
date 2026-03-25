// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Clawy",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Clawy",
            path: "Sources/Clawy"
        )
    ]
)
