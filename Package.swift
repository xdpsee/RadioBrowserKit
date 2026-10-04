// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "RadioBrowserKit",
    platforms: [.iOS(.v15), .macOS(.v12)],
    products: [
        .library(name: "RadioBrowserKit", targets: ["RadioBrowserKit"]),
    ],
    targets: [
        .target(name: "RadioBrowserKit"),
        .testTarget(name: "RadioBrowserKitTests", dependencies: ["RadioBrowserKit"]),
    ]
)
