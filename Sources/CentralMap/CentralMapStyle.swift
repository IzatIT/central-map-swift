import Foundation

/// Сборка компактного стиля MapLibre над источником `central` (чистая подложка для
/// оверлеев). Тайлы/шрифты несут API-ключ. MLNMapView загружает стиль по URL, поэтому
/// JSON пишется во временный файл, и используется его file-URL.
public enum CentralMapStyle {

    /// Ключи слоёв для code-режима «показать списком» → id слоёв этого компактного стиля.
    /// Нативный стиль проще веб-каталога, поэтому ключей меньше (см. доки «Названия слоёв»).
    /// POI-категории (`poi.<class>` / `poigroup.<group>`) включают общий слой `poi`.
    public static let layerKeys: [String: [String]] = [
        "base.green": ["landcover"],
        "base.water": ["water"],
        "base.roads": ["road", "road-casing"],
        "base.buildings": ["building"],
        "base.places": ["place-labels"],
        "base.poi": ["poi"],
    ]

    /// id всех переключаемых слоёв (фон `bg` всегда виден).
    public static let toggleableIds: Set<String> = ["landcover", "water", "road", "road-casing", "building", "place-labels", "poi"]

    /// По списку ключей → множество видимых id (poi.* / poigroup.* включают слой `poi`).
    public static func visibleLayerIds(for only: [String]) -> Set<String> {
        var ids = Set<String>()
        for k in only {
            if let m = layerKeys[k] { ids.formUnion(m) }
            else if k.hasPrefix("poi.") || k.hasPrefix("poigroup.") { ids.insert("poi") }
        }
        return ids
    }

    /// Стиль как словарь JSON. `only` — показать ТОЛЬКО эти слои списком (см. layerKeys).
    public static func json(_ config: CentralMapConfig, dark: Bool = false, only: [String]? = nil) -> [String: Any] {
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
            ["id": "poi", "type": "symbol", "source": "central", "source-layer": "poi", "minzoom": 14,
             "layout": ["icon-image": ["coalesce", ["get", "class"], "marker"],
                        "icon-size": ["interpolate", ["linear"], ["zoom"], 14, 0.5, 18, 0.62],
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
            "glyphs": config.fontsTemplate,
            "sprite": config.spriteTemplate,
            "sources": [
                "central": [
                    "type": "vector",
                    "tiles": [config.tilesTemplate],
                    "minzoom": 0,
                    "maxzoom": 14,
                    "attribution": "© OpenStreetMap contributors",
                ],
            ],
            "layers": layers,
        ]
    }

    /// Записать стиль во временный файл и вернуть его URL (для MLNMapView styleURL).
    public static func temporaryStyleURL(_ config: CentralMapConfig, dark: Bool = false, only: [String]? = nil) -> URL {
        let dict = json(config, dark: dark, only: only)
        let data = (try? JSONSerialization.data(withJSONObject: dict)) ?? Data("{}".utf8)
        // Уникальное имя по конфигу (ключ/база/тема/набор слоёв), чтобы две карты с разными
        // ключами/наборами не перетирали один файл и MapLibre не отдавал устаревший стиль.
        let tag = abs("\(config.tilesTemplate)|\(config.fontsTemplate)|\((only ?? []).sorted().joined(separator: ","))".hashValue)
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
