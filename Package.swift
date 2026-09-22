// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Glim",
    platforms: [.macOS("26.0")],
    products: [
        .library(name: "GlimCore", targets: ["GlimCore"])
    ],
    targets: [
        .target(name: "GlimCore"),
        .testTarget(name: "GlimCoreTests", dependencies: ["GlimCore"]),
    ],
    swiftLanguageModes: [.v6]
)
