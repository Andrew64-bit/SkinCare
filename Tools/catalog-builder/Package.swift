// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "catalog-builder",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "catalog-builder", targets: ["catalog-builder"])
    ],
    dependencies: [
        .package(path: "../../Packages/SkinCareKit")
    ],
    targets: [
        .target(
            name: "CatalogBuilderCore",
            dependencies: [.product(name: "SkinCareKit", package: "SkinCareKit")],
            swiftSettings: [.enableUpcomingFeature("StrictConcurrency")]
        ),
        .executableTarget(name: "catalog-builder", dependencies: ["CatalogBuilderCore"]),
        .testTarget(
            name: "CatalogBuilderCoreTests",
            dependencies: ["CatalogBuilderCore"],
            resources: [.copy("Fixtures")]
        )
    ]
)
