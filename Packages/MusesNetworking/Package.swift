// swift-tools-version: 6.0
import PackageDescription

let package = Package(name: "MusesNetworking", platforms: [.iOS(.v18), .macOS(.v14)], products: [.library(name: "MusesNetworking", targets: ["MusesNetworking"])], targets: [.target(name: "MusesNetworking"), .testTarget(name: "MusesNetworkingTests", dependencies: ["MusesNetworking"])])
