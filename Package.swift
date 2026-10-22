// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MacNetMonitor",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "MacNetMonitor",
            targets: ["MacNetMonitor"]
        )
    ],
    targets: [
        .executableTarget(
            name: "MacNetMonitor",
            path: "Sources/MacNetMonitor"
        ),
        .testTarget(
            name: "MacNetMonitorTests",
            dependencies: ["MacNetMonitor"],
            path: "Tests/MacNetMonitorTests"
        ),
    ]
)
