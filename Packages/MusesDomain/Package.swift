// swift-tools-version: 6.0
import PackageDescription

let package = Package(name: "MusesDomain", platforms: [.iOS(.v18), .macOS(.v14)], products: [.library(name: "MusesDomain", targets: ["MusesDomain"])], targets: [.target(name: "MusesDomain"), .testTarget(name: "MusesDomainTests", dependencies: ["MusesDomain"])])
