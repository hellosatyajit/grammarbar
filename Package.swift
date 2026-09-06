// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GrammarBar",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "GrammarBar", targets: ["GrammarBar"])],
    targets: [
        .executableTarget(
            name: "GrammarBar",
            path: "Sources/GrammarBar",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("Security")
            ]
        )
    ],
    swiftLanguageModes: [.v5]
)
