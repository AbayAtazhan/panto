// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Panto",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "Panto", targets: ["Panto"])
    ],
    targets: [
        .executableTarget(
            name: "Panto",
            path: "Sources/Panto",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
