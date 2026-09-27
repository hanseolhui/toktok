// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "TokTokCore",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "TokTokCore", targets: ["TokTokCore"]),
        .executable(name: "toktok-demo", targets: ["toktok-demo"]),
    ],
    targets: [
        .target(name: "CMultitouch"),
        .target(name: "TokTokCore", dependencies: ["CMultitouch"]),
        .executableTarget(name: "toktok-demo", dependencies: ["TokTokCore"]),
    ]
)
