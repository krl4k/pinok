// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Pinok",
    platforms: [.macOS("26.0")],
    products: [
        .executable(name: "Pinok", targets: ["Pinok"]),
        .library(name: "PinokKit", targets: ["PinokKit"]),
    ],
    targets: [
        // Интерфейс и логика — библиотека, чтобы работали превью в Xcode и тесты.
        .target(name: "PinokKit", path: "Sources/PinokKit"),
        .executableTarget(name: "Pinok", dependencies: ["PinokKit"], path: "Sources/Pinok"),
        .testTarget(name: "PinokKitTests", dependencies: ["PinokKit"], path: "Tests/PinokKitTests"),
    ]
)
