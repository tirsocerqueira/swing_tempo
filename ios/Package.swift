// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GolfTempoTrainer",
    platforms: [
        .iOS(.v18),
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "GolfTempoTrainer",
            targets: ["GolfTempoTrainer"]
        ),
        .executable(
            name: "GolfTempoTrainerTests",
            targets: ["GolfTempoTrainerTests"]
        )
    ],
    targets: [
        .target(name: "GolfTempoTrainer"),
        .executableTarget(
            name: "GolfTempoTrainerTests",
            dependencies: ["GolfTempoTrainer"],
            path: "Tests/GolfTempoTrainerTests"
        )
    ]
)
