// swift-tools-version: 6.0
import PackageDescription

let package = Package(name: "MusesCatalog", platforms: [.iOS(.v18), .macOS(.v14)], products: [.library(name: "MusesCatalog", targets: ["MusesCatalog"])], dependencies: [.package(path: "../MusesNetworking")], targets: [.target(name: "MusesCatalog", dependencies: ["MusesNetworking"]), .testTarget(name: "MusesCatalogTests", dependencies: ["MusesCatalog", "MusesNetworking"], resources: [.process("Fixtures")])])
