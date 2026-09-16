import Foundation

/// Конфигурация карты central.kg: адрес бэкенда + API-ключ сервиса `map`.
///
/// Ключ выпускается в auth.central.kg (привязан к сервису — ключ `map` не действует на
/// другие). Уходит как `?key=` в запросах тайлов/шрифтов (нативный движок не шлёт
/// заголовки) и как `X-API-Key` в REST-вызовах.
public struct CentralMapConfig {
    public var apiBase: String
    public var apiKey: String?
    public var tilesURL: String?

    public init(apiBase: String = "https://map.central.kg", apiKey: String? = nil, tilesURL: String? = nil) {
        self.apiBase = apiBase
        self.apiKey = apiKey
        self.tilesURL = tilesURL
    }

    private var base: String {
        var b = apiBase
        while b.hasSuffix("/") { b.removeLast() }
        return b
    }

    /// Шаблон тайлов с ключом.
    public var tilesTemplate: String {
        withKey(tilesURL ?? "\(base)/api/tiles/{z}/{x}/{y}.pbf")
    }

    /// Шаблон шрифтов (glyphs) с ключом.
    public var fontsTemplate: String {
        withKey("\(base)/fonts/{fontstack}/{range}.pbf")
    }

    /// База sprite-листа POI-бейджей (MapLibre добавит .json/.png/@2x). Публичный, без ключа.
    public var spriteTemplate: String { "\(base)/sprite" }

    /// База REST-эндпоинтов, напр. `https://map.central.kg/api`.
    public var restBase: String { "\(base)/api" }

    /// Заголовки для REST (добавляет X-API-Key при наличии ключа).
    public var headers: [String: String] {
        guard let key = apiKey, !key.isEmpty else { return [:] }
        return ["X-API-Key": key]
    }

    private func withKey(_ url: String) -> String {
        guard let key = apiKey, !key.isEmpty else { return url }
        let sep = url.contains("?") ? "&" : "?"
        let enc = key.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? key
        return "\(url)\(sep)key=\(enc)"
    }
}

extension CharacterSet {
    /// Безопасные символы для значения query-параметра.
    static let urlQueryValueAllowed: CharacterSet = {
        var cs = CharacterSet.urlQueryAllowed
        cs.remove(charactersIn: "&=?+")
        return cs
    }()
}
