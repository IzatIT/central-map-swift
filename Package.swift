// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "CentralMap",
    platforms: [.iOS(.v13)],
    products: [
        .library(name: "CentralMap", targets: ["CentralMap"]),
    ],
    dependencies: [
        // MapLibre Native iOS (SPM-дистрибутив). Модуль `import MapLibre`, классы MLN*.
        .package(url: "https://github.com/maplibre/maplibre-gl-native-distribution", from: "6.0.0"),
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
