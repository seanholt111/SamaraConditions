// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SamaraCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "SamaraCore", targets: ["SamaraCore"]),
    ],
    targets: [
        .target(name: "SamaraCore"),
        .testTarget(name: "SamaraCoreTests", dependencies: ["SamaraCore"]),
    ]
)
