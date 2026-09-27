// swift-tools-version: 6.0
import PackageDescription

let package = Package(name: "MusesPersistence", platforms: [.iOS(.v18), .macOS(.v14)], products: [.library(name: "MusesPersistence", targets: ["MusesPersistence"])], dependencies: [.package(path: "../MusesDomain"), .package(path: "../MusesQueue")], targets: [.target(name: "MusesPersistence", dependencies: ["MusesDomain", "MusesQueue"], linkerSettings: [.linkedLibrary("sqlite3")]), .testTarget(name: "MusesPersistenceTests", dependencies: ["MusesPersistence", "MusesDomain", "MusesQueue"])])
