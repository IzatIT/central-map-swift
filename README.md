# CentralMap (Swift / iOS)

Карта **central.kg** (Кыргызстан и Казахстан) для iOS —
[MapLibre Native](https://github.com/maplibre/maplibre-native) со стилем сайта
`map.central.kg`, маркерами, линиями, кластерами и REST-клиентом (поиск, маршруты, изохроны).
SwiftUI + UIKit.

> Часть экосистемы: web — `@centralkg/map*`, Flutter — `central_map`, React Native —
> `@centralkg/map-react-native`, Android — `kg.central:central-map-android`.
> Документация: https://map.central.kg/docs

## Установка (Swift Package Manager)

В Xcode: **File → Add Package Dependencies…** и адрес
`https://github.com/IzatIT/central-map-swift`, либо в `Package.swift`:

```swift
.package(url: "https://github.com/IzatIT/central-map-swift", from: "0.2.0"),
// продукт: "CentralMap"
```

Зависимость MapLibre Native iOS подтянется автоматически. Минимум iOS 13
(REST-клиент `CentralMapAPI` — iOS 15+, async/await).

## Стиль и API-ключ

Стиль карты берётся с сервера — тот же, что у сайта: `https://map.central.kg/style/light.json`
или `dark.json` (параметр `dark`). Значки, шрифты, рельеф и версия тайлов приходят вместе со
стилем, поэтому правки сайта доходят до приложения без обновления пакета. Стиль, тайлы, шрифты и
значки открыты — **ключ им не нужен**.

Ключ сервиса `map` (генерируется в **auth.central.kg → «API-ключи»**; ключ одного сервиса не
действует на другом) нужен только REST — поиск, маршруты, `meta`. Уходит заголовком `X-API-Key`.

```swift
let config = CentralMapConfig(apiKey: "ck_map_…")
```

## Карта, маркеры, линии (SwiftUI)

```swift
import SwiftUI
import CentralMap

struct MapScreen: View {
    @Environment(\.colorScheme) private var scheme
    let config = CentralMapConfig(apiKey: "ck_map_…")

    var body: some View {
        CentralMap(config: config, dark: scheme == .dark,
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

Параметры: `dark` — тема стиля; `center`, `zoom` — начальный вид; `minZoom` — наименьший масштаб
(по умолчанию 2: тайлы есть с z2, Кыргызстан и Казахстан целиком); `layers` — показать только эти
слои; `styleURL` — свой стиль вместо стиля сервера. Тема выбирается при создании карты.

`onReady` отдаёт `CentralMapController`: `addMarker(_:color:title:onTap:)`,
`addPolyline(_:color:width:opacity:)`, `removePolyline(_:)`, `addZone`, `addCluster`,
`startZoneDraw`, `showOnlyLayers`, `setLayerVisible`, доступ к `mapView` (полный `MLNMapView`).
В UIKit создавайте карту через `CentralMapController(config:).makeMapView(...)` с теми же параметрами.

Логотип MapLibre и кнопка атрибуции скрыты — покажите «© OpenStreetMap contributors» в своём
интерфейсе (этого требует лицензия данных OpenStreetMap).

## Слои списком

Ключи — те же, что на сайте (https://map.central.kg/docs, «Названия слоёв»): `base.buildings`,
`base.roads`, `base.road_labels`, `base.road_signs`, `base.traffic_signals`, `base.rivers`,
`base.water`, `base.green`, `base.builtup`, `base.terrain`, `base.railway`, `base.aeroway`,
`base.parking`, `base.power`, `base.military`, `base.boundaries`, `base.places`. Места —
`base.poi`, `poi.<class>` или `poigroup.<group>`: любой из них включает все слои мест.

```swift
CentralMap(config: config, layers: ["base.roads", "base.water", "poigroup.food"]) { map in
    map.showOnlyLayers(["base.roads", "base.poi"])   // сменить набор позже
}
```

## REST API

```swift
let api = CentralMapAPI(config: config)
let hits  = try await api.search("Ала-Тоо", limit: 10)
let route = try await api.route(from: .init(latitude: 42.87, longitude: 74.59),
                                to: .init(latitude: 42.89, longitude: 74.85), mode: "car")
let iso   = try await api.isochrone(point: .init(latitude: 42.87, longitude: 74.59),
                                    minutes: [5, 10, 15])
let poi   = try await api.poiMeta()
let meta  = try await api.meta()   // tilesVersion, minZoom, maxZoom, raw (страны, дата данных)
```

База — `https://map.central.kg/api` (сервер меняется через `apiBase`). Ошибка HTTP —
`CentralMapError.http(статус)`.

## Переход с 0.1

Код 0.1 собирается без правок. Что изменилось в поведении:

- карта берёт стиль сервера (как сайт) вместо встроенного компактного; ключи слоёв — как на сайте
  (прежние шесть `base.*` работают);
- `?key=` к тайлам и шрифтам больше не добавляется;
- наименьший масштаб — 2;
- устарело: `CentralMapStyle.json`, `temporaryStyleURL`, `tilesTemplate`, `fontsTemplate`,
  `spriteTemplate`, `tilesURL`. Со своими тайлами (`tilesURL`) карта строится прежним встроенным
  стилем, как в 0.1; свой стиль целиком — `styleURL`.

## Лицензия

MIT
