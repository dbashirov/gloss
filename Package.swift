// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "Engl",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "Engl", targets: ["Engl"]),
        .library(name: "EnglCore", targets: ["EnglCore"]),
    ],
    targets: [
        .target(name: "EnglCore"),
        .executableTarget(name: "Engl", dependencies: ["EnglCore"]),
        .testTarget(
            name: "EnglCoreTests",
            dependencies: ["EnglCore"],
            resources: [.process("Fixtures")]
        ),
    ]
)
