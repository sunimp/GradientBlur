// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "GradientBlur",
    platforms: [.iOS(.v15)],
    products: [
        .library(
            name: "GradientBlur",
            targets: ["GradientBlur"]
        ),
    ],
    targets: [
        .target(
            name: "GradientBlur"
        ),
        .testTarget(
            name: "GradientBlurTests",
            dependencies: ["GradientBlur"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
