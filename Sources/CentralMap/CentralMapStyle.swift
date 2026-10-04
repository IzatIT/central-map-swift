import Foundation

/// Слои карты для режима «показать списком» (`makeMapView(layers:)`, `showOnlyLayers(_:)`) и
/// прежний встроенный стиль (устарело).
///
/// Карта берёт стиль сервера — тот же, что у сайта (`CentralMapConfig.styleURL(dark:)`), поэтому
/// ключи слоёв те же, что в вебе (https://map.central.kg/docs, «Названия слоёв»). POI-категории
/// (`poi.<class>` / `poigroup.<group>`) и `base.poi` включают все слои мест целиком.
public enum CentralMapStyle {

    /// id слоёв мест (значки и подписи) в стиле сервера.
    public static let poiLayerIds: [String] = [
        "transport-roadside", "transport-roadside-label",
        "poi-z11", "poi-z13", "poi-z14", "poi-z15", "poi-z16", "poi-z17", "poi-z18",
    ]

    // Ключ → id слоёв стиля сервера (как каталог сайта, src/centralCatalog.ts фронта карты).
    private static let serverKeys: [String: [String]] = [
        "base.buildings": ["building-fill", "building-3d"],
        "base.roads": ["road-casing-minor", "road-casing-major", "road-fill-minor", "road-fill-major",
                       "road-path", "road-centerline", "road-oneway", "bridge", "roadtunnel"],
        "base.road_labels": ["road-label"],
        "base.traffic_signals": ["roadsign-signals"],
        "base.road_signs": ["roadsign-priority", "crossing-zebra", "barrier"],
        "base.rivers": ["waterway", "hl-waterway-label"],
        "base.water": ["water-fill", "water-outline", "water_struct", "hl-water-name"],
        "base.green": ["landcover-green", "tree"],
        "base.builtup": ["landcover-builtup", "landcover-farm", "landcover-sand", "landcover-ice", "landcover-wetland"],
        "base.terrain": ["hillshade", "peak-circle", "peak-label", "natural_line", "natpoi-circle", "natpoi-label"],
        "base.railway": ["railway", "aerialway", "piste"],
        "base.aeroway": ["aeroway", "aeroway-poly"],
        "base.parking": ["parking-area"],
        "base.power": ["power"],
        "base.military": ["military"],
        "base.boundaries": ["boundary-admin"],
        "base.places": ["place-city", "place-town", "place-village", "place-suburb", "place-minor"],
        "base.poi": poiLayerIds,
    ]

    // id прежнего встроенного стиля (свои тайлы, tilesURL): с ним ключи тоже работают.
    private static let legacyKeys: [String: [String]] = [
        "base.green": ["landcover"],
        "base.water": ["water"],
        "base.roads": ["road", "road-casing"],
        "base.buildings": ["building"],
        "base.places": ["place-labels"],
        "base.poi": ["poi"],
    ]

    /// Ключ слоя (`base.*`) → id слоёв: стиля сервера и прежнего встроенного (лишние id карта не найдёт).
    public static let layerKeys: [String: [String]] = serverKeys.merging(legacyKeys) { $0 + $1 }

    /// id всех переключаемых слоёв (фон, подсветки `hl-*` и `admin-hit` всегда на месте).
    public static let toggleableIds: Set<String> = Set(layerKeys.values.joined())

    /// По списку ключей → множество видимых id (poi.* / poigroup.* включают все слои мест).
    public static func visibleLayerIds(for only: [String]) -> Set<String> {
        var ids = Set<String>()
        for k in only {
            if let m = layerKeys[k] { ids.formUnion(m) }
            else if k.hasPrefix("poi.") || k.hasPrefix("poigroup.") { ids.formUnion(layerKeys["base.poi"] ?? []) }
        }
        return ids
    }

    /// Какой стиль грузить: свой адрес → прежний встроенный стиль, если заданы свои тайлы
    /// (устаревший `tilesURL`, как в 0.1) → стиль сервера по теме.
    static func resolvedStyleURL(_ config: CentralMapConfig, dark: Bool, only: [String]?, custom: URL?) -> URL {
        if let custom { return custom }
        if config.customTilesURL != nil { return legacyStyleFileURL(config, dark: dark, only: only) }
        return config.styleURL(dark: dark)
    }

    /// Прежний встроенный компактный стиль как словарь JSON. Карта больше его не берёт: стиль —
    /// с сервера (`CentralMapConfig.styleURL(dark:)`).
    @available(*, deprecated, message: "Стиль карты — с сервера: CentralMapConfig.styleURL(dark:). Встроенный стиль SDK берёт только для своих тайлов (tilesURL).")
    public static func json(_ config: CentralMapConfig, dark: Bool = false, only: [String]? = nil) -> [String: Any] {
        legacyJSON(config, dark: dark, only: only)
    }

    /// Записать прежний встроенный стиль во временный файл и вернуть его URL.
    @available(*, deprecated, message: "Стиль карты — с сервера: CentralMapConfig.styleURL(dark:). Встроенный стиль SDK берёт только для своих тайлов (tilesURL).")
    public static func temporaryStyleURL(_ config: CentralMapConfig, dark: Bool = false, only: [String]? = nil) -> URL {
        legacyStyleFileURL(config, dark: dark, only: only)
    }

    // MARK: - Прежний встроенный стиль (0.1): тайлы/шрифты без ключа, лист значков сервера по теме

    static func legacyJSON(_ config: CentralMapConfig, dark: Bool, only: [String]?) -> [String: Any] {
        let p = dark ? darkPalette : lightPalette
        var layers: [[String: Any]] = [
            ["id": "bg", "type": "background", "paint": ["background-color": p.bg]],
            ["id": "landcover", "type": "fill", "source": "central", "source-layer": "landcover",
             "paint": ["fill-color": p.green, "fill-opacity": 0.6]],
            ["id": "water", "type": "fill", "source": "central", "source-layer": "water",
             "paint": ["fill-color": p.water]],
            ["id": "road-casing", "type": "line", "source": "central", "source-layer": "road", "minzoom": 6,
             "layout": ["line-cap": "round", "line-join": "round"],
             "paint": ["line-color": p.roadCasing,
                       "line-width": ["interpolate", ["linear"], ["zoom"], 7, 0.5, 12, 2.5, 16, 8, 20, 22]]],
            ["id": "road", "type": "line", "source": "central", "source-layer": "road", "minzoom": 6,
             "layout": ["line-cap": "round", "line-join": "round"],
             "paint": ["line-color": p.road,
                       "line-width": ["interpolate", ["linear"], ["zoom"], 7, 0.2, 12, 1.5, 16, 6, 20, 18]]],
            ["id": "building", "type": "fill", "source": "central", "source-layer": "building", "minzoom": 13,
             "paint": ["fill-color": p.building, "fill-opacity": 0.85]],
            ["id": "place-labels", "type": "symbol", "source": "central", "source-layer": "place",
             "layout": ["text-field": ["coalesce", ["get", "name:ru"], ["get", "name"]],
                        "text-font": ["Noto Sans Regular"],
                        "text-size": ["interpolate", ["linear"], ["zoom"], 4, 11, 10, 15, 14, 19],
                        "text-max-width": 8],
             "paint": ["text-color": p.text, "text-halo-color": p.textHalo, "text-halo-width": 1.4]],
            // значки листа сервера ~30 px — размер 0.8–1
            ["id": "poi", "type": "symbol", "source": "central", "source-layer": "poi", "minzoom": 14,
             "layout": ["icon-image": ["coalesce", ["get", "class"], "marker"],
                        "icon-size": ["interpolate", ["linear"], ["zoom"], 14, 0.8, 18, 1.0],
                        "icon-allow-overlap": false, "text-optional": true,
                        "text-field": ["coalesce", ["get", "name:ru"], ["get", "name"]],
                        "text-font": ["Noto Sans Regular"], "text-size": 11,
                        "text-anchor": "top", "text-offset": [0, 1.1], "text-max-width": 8],
             "paint": ["text-color": p.text, "text-halo-color": p.textHalo, "text-halo-width": 1.4]],
        ]
        if let only = only {
            let vis = visibleLayerIds(for: only)
            layers = layers.map { layer in
                guard let id = layer["id"] as? String, id != "bg", !vis.contains(id) else { return layer }
                var l = layer
                var layout = (l["layout"] as? [String: Any]) ?? [:]
                layout["visibility"] = "none"
                l["layout"] = layout
                return l
            }
        }
        return [
            "version": 8,
            "name": dark ? "central-dark" : "central-light",
            "glyphs": config.legacyFontsTemplate,
            "sprite": config.legacySpriteURL(dark: dark),
            "sources": [
                "central": [
                    "type": "vector",
                    "tiles": [config.legacyTilesTemplate],
                    "minzoom": 0,
                    "maxzoom": 14,
                    "attribution": "© OpenStreetMap contributors",
                ],
            ],
            "layers": layers,
        ]
    }

    /// MLNMapView грузит стиль по URL, поэтому JSON пишется во временный файл.
    static func legacyStyleFileURL(_ config: CentralMapConfig, dark: Bool, only: [String]?) -> URL {
        let dict = legacyJSON(config, dark: dark, only: only)
        let data = (try? JSONSerialization.data(withJSONObject: dict)) ?? Data("{}".utf8)
        // Уникальное имя по конфигу (база/тайлы/тема/набор слоёв), чтобы две карты с разными
        // настройками не перетирали один файл и MapLibre не отдавал устаревший стиль.
        let tag = UInt(bitPattern: "\(config.legacyTilesTemplate)|\(config.legacyFontsTemplate)|\((only ?? []).sorted().joined(separator: ","))".hashValue)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("central-map-\(dark ? "dark" : "light")-\(tag).json")
        try? data.write(to: url)
        return url
    }

    private struct Palette {
        let bg, water, green, road, roadCasing, building, text, textHalo: String
    }
    private static let lightPalette = Palette(
        bg: "#f4f2ec", water: "#a9d3f0", green: "#cfe6c4", road: "#ffffff",
        roadCasing: "#d9d4c8", building: "#e4ddcf", text: "#3a3a3a", textHalo: "#ffffff")
    private static let darkPalette = Palette(
        bg: "#11151c", water: "#16324a", green: "#1b2a1f", road: "#3a4252",
        roadCasing: "#222936", building: "#1b2129", text: "#d6dae0", textHalo: "#0c0f14")
}
