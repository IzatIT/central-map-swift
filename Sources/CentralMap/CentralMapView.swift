#if canImport(SwiftUI) && canImport(UIKit)
import CoreLocation
import MapLibre
import SwiftUI

/// SwiftUI-карта central.kg. Через `onReady` отдаёт `CentralMapController` — добавляйте
/// маркеры и линии. Стиль — с сервера, как у сайта (`dark` — тёмная тема); `layers` — показать
/// только эти слои; `minZoom` — наименьший масштаб (по умолчанию 2); `styleURL` — свой стиль.
///
/// ```swift
/// CentralMap(config: CentralMapConfig(apiKey: "ck_map_…"), dark: true) { map in
///     map.addMarker(CLLocationCoordinate2D(latitude: 42.87, longitude: 74.59), color: .cyan)
///     map.addPolyline([
///         CLLocationCoordinate2D(latitude: 42.8, longitude: 74.5),
///         CLLocationCoordinate2D(latitude: 42.9, longitude: 74.7),
///     ], color: .systemIndigo)
/// }
/// .ignoresSafeArea()
/// ```
public struct CentralMap: UIViewRepresentable {
    private let config: CentralMapConfig
    private let dark: Bool
    private let center: CLLocationCoordinate2D
    private let zoom: Double
    private let layers: [String]?
    private let minZoom: Double
    private let styleURL: URL?
    private let onReady: ((CentralMapController) -> Void)?

    public init(config: CentralMapConfig,
                dark: Bool = false,
                center: CLLocationCoordinate2D = .kgCenter,
                zoom: Double = 6,
                layers: [String]? = nil,
                minZoom: Double = CentralMapConfig.defaultMinZoom,
                styleURL: URL? = nil,
                onReady: ((CentralMapController) -> Void)? = nil) {
        self.config = config
        self.dark = dark
        self.center = center
        self.zoom = zoom
        self.layers = layers
        self.minZoom = minZoom
        self.styleURL = styleURL
        self.onReady = onReady
    }

    public func makeCoordinator() -> CentralMapController {
        CentralMapController(config: config)
    }

    public func makeUIView(context: Context) -> MLNMapView {
        let controller = context.coordinator
        controller.onReady = onReady
        return controller.makeMapView(dark: dark, center: center, zoom: zoom,
                                      layers: layers, minZoom: minZoom, styleURL: styleURL)
    }

    public func updateUIView(_ uiView: MLNMapView, context: Context) {}
}
#endif
