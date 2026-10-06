// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Resus",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Resus", targets: ["Resus"])],
    targets: [
        .target(name: "ResusCore"),
        .executableTarget(name: "Resus", dependencies: ["ResusCore"]),
        .testTarget(name: "ResusCoreTests", dependencies: ["ResusCore"])
    ]
)
