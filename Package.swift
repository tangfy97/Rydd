// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Rydd",
    platforms: [.macOS("26.0")],
    products: [
        .executable(name: "rydd", targets: ["rydd"]),
        .executable(name: "RyddApp", targets: ["RyddApp"]),
    ],
    targets: [
        // The engine: scanning, rules, similarity, on-device LLM, file moves + undo. No networking.
        .target(name: "RyddCore", path: "Sources/RyddCore"),
        // Command-line preview / evaluation tool.
        .executableTarget(name: "rydd", dependencies: ["RyddCore"], path: "Sources/rydd"),
        // Menu bar app. Packaged into Rydd.app by Scripts/build_app.sh.
        .executableTarget(name: "RyddApp", dependencies: ["RyddCore"], path: "Sources/RyddApp"),
    ],
    swiftLanguageModes: [.v5]
)
