// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "GameLogic",
    products: [
        .library(name: "GameLogic", targets: ["GameLogic"]),
    ],
    targets: [
        .target(name: "GameLogic", path: "Sources/GameLogic"),
        .testTarget(name: "GameLogicTests", dependencies: ["GameLogic"],
                    path: "Tests/GameLogicTests"),
    ]
)
