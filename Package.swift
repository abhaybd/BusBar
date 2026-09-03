// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "BusBar",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "BusBar",
            path: "Sources/BusBar"
        )
    ]
)
