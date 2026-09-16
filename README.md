# CentralMap (Swift / iOS)

Карта Кыргызстана **central.kg** для iOS — настроенная карта
[MapLibre Native](https://github.com/maplibre/maplibre-native) поверх наших векторных
тайлов `map.central.kg`, с маркерами, линиями и REST-клиентом (поиск, маршруты, изохроны).
SwiftUI + UIKit.

> Часть экосистемы: web — `@centralkg/map*`, Flutter — `central_map`, React Native —
> `@centralkg/map-react-native`. Документация: https://map.central.kg/docs

## Установка (Swift Package Manager)

В Xcode: **File → Add Package Dependencies…** и URL этого репозитория, либо в `Package.swift`:

```swift
.package(url: "https://github.com/IzatIT/central", from: "0.1.0"),
// продукт: "CentralMap"
```

Зависимость MapLibre Native iOS подтянется автоматически. Минимум iOS 13
(REST-клиент `CentralMapAPI` — iOS 15+, async/await).

## API-ключ

Карта работает по **ключу сервиса `map`** (генерируется в **auth.central.kg → «API-ключи»**;
ключ одного сервиса не действует на другом). Уходит как `?key=` в тайлы/шрифты и как
`X-API-Key` в REST.

```swift
let config = CentralMapConfig(apiKey: "ck_map_…")
```

## Карта, маркеры, линии (SwiftUI)

```swift
import SwiftUI
import CentralMap

struct MapScreen: View {
    let config = CentralMapConfig(apiKey: "ck_map_…")
    var body: some View {
        CentralMap(config: config, dark: true,
                   center: CLLocationCoordinate2D(latitude: 42.86, longitude: 74.9),
                   zoom: 9) { map in
            map.addMarker(.init(latitude: 42.87, longitude: 74.59), color: .cyan)        // Бишкек
            map.addPolyline([
                .init(latitude: 42.87, longitude: 74.59),
                .init(latitude: 42.89, longitude: 74.85),
            ], color: .systemIndigo, width: 4)
        }
        .ignoresSafeArea()
    }
}
```

`onReady` отдаёт `CentralMapController`: `addMarker(_:color:title:onTap:)`,
`addPolyline(_:color:width:opacity:)`, `removePolyline(_:)`, доступ к `mapView` (полный
`MLNMapView`). В UIKit создавайте карту через `CentralMapController.makeMapView(...)`.

## REST API

```swift
let api = CentralMapAPI(config: config)
let hits  = try await api.search("Ала-Тоо", limit: 10)
let route = try await api.route(from: .init(latitude: 42.87, longitude: 74.59),
                                to: .init(latitude: 42.89, longitude: 74.85), mode: "car")
let iso   = try await api.isochrone(point: .init(latitude: 42.87, longitude: 74.59),
                                    minutes: [5, 10, 15])
let meta  = try await api.poiMeta()
```

База — `https://map.central.kg/api` (переопределяется через `apiBase`/`tilesURL`).

## Лицензия

MIT
