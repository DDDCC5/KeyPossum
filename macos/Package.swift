// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KeyPossum",
    platforms: [.macOS("26.0")],
    products: [.executable(name: "KeyPossum", targets: ["KeyPossum"])],
    targets: [
        .target(name: "KeyPossumCore"),
        .executableTarget(name: "KeyPossum", dependencies: ["KeyPossumCore"]),
        .executableTarget(name: "SessionTests", dependencies: ["KeyPossumCore"], path: "Tests/KeyPossumCoreTests")
    ],
    swiftLanguageModes: [.v5]
)
