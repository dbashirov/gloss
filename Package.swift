// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "Gloss",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "Gloss", targets: ["Gloss"]),
    ],
    targets: [
        .target(name: "GlossCore"),
        .executableTarget(name: "Gloss", dependencies: ["GlossCore"]),
        .testTarget(
            name: "GlossCoreTests",
            dependencies: ["GlossCore"],
            resources: [.process("Fixtures")]
        ),
    ]
)
