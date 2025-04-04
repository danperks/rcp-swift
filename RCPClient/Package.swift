// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "RCPClient",
    platforms: [
        .iOS(.v14),
        .macOS(.v11)
    ],
    products: [
        .library(
            name: "RCPClient",
            targets: ["RCPClient"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "RCPClient",
            dependencies: []),
        .testTarget(
            name: "RCPClientTests",
            dependencies: ["RCPClient"]),
    ]
) 