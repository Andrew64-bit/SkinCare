// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SkinCareKit",
    defaultLocalization: "it",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "SkinCareKit", targets: ["SkinCareKit"])
    ],
    targets: [
        .target(
            name: "SkinCareKit",
            swiftSettings: [.enableUpcomingFeature("StrictConcurrency")]
        ),
        .testTarget(
            name: "SkinCareKitTests",
            dependencies: ["SkinCareKit"],
            resources: [.copy("Fixtures")]
        )
    ]
)
