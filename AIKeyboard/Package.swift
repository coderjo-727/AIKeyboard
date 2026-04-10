// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "AIKeyboard",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
    ],
    products: [
        .library(
            name: "AIKeyboardCore",
            targets: ["AIKeyboardCore"]
        ),
    ],
    targets: [
        .target(
            name: "AIKeyboardCore"
        ),
        .testTarget(
            name: "AIKeyboardCoreTests",
            dependencies: ["AIKeyboardCore"]
        ),
    ]
)
