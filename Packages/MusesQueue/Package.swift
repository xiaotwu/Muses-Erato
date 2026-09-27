// swift-tools-version: 6.0
import PackageDescription

let package = Package(name: "MusesQueue", platforms: [.iOS(.v18), .macOS(.v14)], products: [.library(name: "MusesQueue", targets: ["MusesQueue"])], dependencies: [.package(path: "../MusesDomain")], targets: [.target(name: "MusesQueue", dependencies: ["MusesDomain"]), .testTarget(name: "MusesQueueTests", dependencies: ["MusesQueue", "MusesDomain"])])
