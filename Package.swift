// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ClaudeMeter",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "ClaudeMeter",
            targets: ["ClaudeMeter"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "ClaudeMeter",
            dependencies: [],
            path: "Sources"
        )
    ]
)
