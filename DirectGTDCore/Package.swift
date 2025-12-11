// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DirectGTDCore",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "DirectGTDCore",
            targets: ["DirectGTDCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.8.0"),
    ],
    targets: [
        .target(
            name: "DirectGTDCore",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
            ]),
        .testTarget(
            name: "DirectGTDCoreTests",
            dependencies: ["DirectGTDCore"]),
    ]
)
