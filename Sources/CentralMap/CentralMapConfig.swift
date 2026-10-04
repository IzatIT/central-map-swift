import Foundation

/// Конфигурация карты central.kg: адрес бэкенда + API-ключ сервиса `map`.
///
/// Стиль карты — с сервера, тот же, что у сайта (`styleURL(dark:)`). Стиль, тайлы, шрифты, значки
/// и рельеф открыты: ключ им не нужен и в их адреса не добавляется (ключ в адресе дробит общий
/// кэш CDN). Ключ выпускается в auth.central.kg (привязан к сервису — ключ `map` не действует на
/// другие) и уходит только заголовком `X-API-Key` в REST-вызовах (поиск, маршрут, meta…).
public struct CentralMapConfig {
    /// Наименьший масштаб карты по умолчанию: тайлы есть с z2 (сервер — `minZoom` в `CentralMapAPI.meta()`).
    public static let defaultMinZoom: Double = 2

    /// Адрес сервера карты: от него строятся адрес стиля и REST.
    public var apiBase: String
    /// Ключ сервиса `map` — только для REST.
    public var apiKey: String?

    /// Свои тайлы (устарело). Если заданы, карта строится прежним встроенным компактным стилем
    /// над ними (как в 0.1); без них — стилем сервера.
    @available(*, deprecated, message: "Свои тайлы — свой стиль: makeMapView(styleURL:). Без tilesURL карта берёт стиль сервера (styleURL(dark:)).")
    public var tilesURL: String? {
        get { customTilesURL }
        set { customTilesURL = newValue }
    }

    /// Хранилище `tilesURL` (внутри SDK — без предупреждения об устаревании).
    var customTilesURL: String?

    public init(apiBase: String = "https://map.central.kg", apiKey: String? = nil, tilesURL: String? = nil) {
        self.apiBase = apiBase
        self.apiKey = apiKey
        self.customTilesURL = tilesURL
    }

    private var base: String {
        var b = apiBase
        while b.hasSuffix("/") { b.removeLast() }
        return b
    }

    /// Адрес стиля сервера (MapLibre style v8, как у сайта): светлый или тёмный. Без ключа.
    public func styleURL(dark: Bool = false) -> URL {
        // кривой apiBase — ошибка настройки: не падаем, берём стиль основного сервера
        URL(string: "\(base)/style/\(theme(dark)).json")
            ?? URL(string: "https://map.central.kg/style/\(theme(dark)).json")!
    }

    /// База REST-эндпоинтов, напр. `https://map.central.kg/api`.
    public var restBase: String { "\(base)/api" }

    /// Заголовки для REST (добавляет X-API-Key при наличии ключа).
    public var headers: [String: String] {
        guard let key = apiKey, !key.isEmpty else { return [:] }
        return ["X-API-Key": key]
    }

    /// Шаблон тайлов (без ключа).
    @available(*, deprecated, message: "Адреса тайлов, шрифтов и значков — в стиле сервера: styleURL(dark:)")
    public var tilesTemplate: String { legacyTilesTemplate }

    /// Шаблон шрифтов (glyphs, без ключа).
    @available(*, deprecated, message: "Адреса тайлов, шрифтов и значков — в стиле сервера: styleURL(dark:)")
    public var fontsTemplate: String { legacyFontsTemplate }

    /// База светлого листа значков (MapLibre добавит .json/.png/@2x).
    @available(*, deprecated, message: "Адреса тайлов, шрифтов и значков — в стиле сервера: styleURL(dark:)")
    public var spriteTemplate: String { legacySpriteURL(dark: false) }

    // MARK: - Адреса прежнего встроенного стиля (свои тайлы, tilesURL). Ключ не добавляется.

    var legacyTilesTemplate: String { customTilesURL ?? "\(base)/api/tiles/{z}/{x}/{y}.pbf" }
    var legacyFontsTemplate: String { "\(base)/fonts/{fontstack}/{range}.pbf" }
    func legacySpriteURL(dark: Bool) -> String { "\(base)/style/sprite/\(theme(dark))" }

    private func theme(_ dark: Bool) -> String { dark ? "dark" : "light" }
}
