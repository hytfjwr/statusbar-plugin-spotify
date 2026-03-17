// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "SpotifyPlugin",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "SpotifyPlugin", type: .dynamic, targets: ["SpotifyPlugin"]),
    ],
    dependencies: [
        .package(url: "https://github.com/hytfjwr/StatusBarKit", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "SpotifyPlugin",
            dependencies: [
                .product(name: "StatusBarKit", package: "StatusBarKit"),
            ]
        ),
    ]
)
