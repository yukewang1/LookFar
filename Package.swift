// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RestCore",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [.library(name: "RestCore", targets: ["RestCore"])],
    targets: [
        .target(name: "RestCore", path: "Core"),
        .testTarget(name: "RestCoreTests", dependencies: ["RestCore"], path: "CoreTests")
    ]
)
