// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "MenuBarKit",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "MenuBarKit", path: "Sources/MenuBarKit")
    ]
)
