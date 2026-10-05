// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "CounterKit",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "CounterKit", targets: ["CounterKit"]),
    ],
    targets: [
        .target(name: "CounterKit"),
        .testTarget(name: "CounterKitTests", dependencies: ["CounterKit"]),
    ]
)
