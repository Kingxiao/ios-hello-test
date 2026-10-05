// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "CounterKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "CounterKit", targets: ["CounterKit"]),
    ],
    targets: [
        .target(name: "CounterKit"),
        .testTarget(name: "CounterKitTests", dependencies: ["CounterKit"]),
    ]
)
