// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "BatteryBeacon",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "BatteryBeacon",
            path: "Sources/BatteryBeacon"
        )
    ]
)
