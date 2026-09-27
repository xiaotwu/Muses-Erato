// swift-tools-version: 6.0
import PackageDescription

let package = Package(name: "MusesIOSOAuth", platforms: [.iOS(.v18), .macOS(.v14)], products: [.library(name: "MusesIOSOAuth", targets: ["MusesIOSOAuth"])], dependencies: [.package(path: "../../../Packages/MusesNetworking"), .package(path: "../../../Packages/MusesCatalog")], targets: [.target(name: "MusesIOSOAuth", dependencies: ["MusesNetworking", "MusesCatalog"]), .testTarget(name: "MusesIOSOAuthTests", dependencies: ["MusesIOSOAuth", "MusesNetworking"])])
