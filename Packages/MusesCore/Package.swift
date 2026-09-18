// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MusesCore",
    platforms: [
        .iOS(.v18),
        .macOS(.v14)
    ],
    products: [
        .library(name: "MusesCore", targets: ["MusesCore"])
    ],
    targets: [
        .target(name: "MusesCore"),
        .testTarget(name: "MusesCoreTests", dependencies: ["MusesCore"])
    ]
)
