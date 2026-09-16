// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "CentralMap",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        // То, что становятся видно внешним пользователям / проектам
        .library(
            name: "CentralMap",
            targets: ["CentralMap"]
        ),
    ],
    dependencies: [
        // Зависимость от MapLibre по полному URL
        .package(
            url: "https://github.com/maplibre/maplibre-gl-native-distribution",
            from: "6.0.0"
        ),
    ],
    targets: [
        .target(
            name: "CentralMap",
            dependencies: [
                .product(name: "MapLibre", package: "maplibre-gl-native-distribution"),
            ]
        ),
    ]
)
