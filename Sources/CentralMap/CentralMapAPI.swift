import CoreLocation
import Foundation

/// Результат поиска (разбирается мягко из ответа /search).
public struct CentralSearchHit {
    public let name: String
    public let coordinate: CLLocationCoordinate2D?
    public let type: String?
    public let raw: [String: Any]
}

public enum CentralMapError: Error {
    case http(Int)
    case badResponse
}

/// REST-клиент карты central.kg (поиск, маршруты, изохроны, POI-мета). Ключ (если задан)
/// уходит заголовком X-API-Key.
@available(iOS 15.0, macOS 12.0, *)
public final class CentralMapAPI {
    public let config: CentralMapConfig
    private let session: URLSession

    public init(config: CentralMapConfig, session: URLSession = .shared) {
        self.config = config
        self.session = session
    }

    /// Поиск / геокодер. near — приоритет результатов рядом.
    public func search(_ q: String, limit: Int = 10, near: CLLocationCoordinate2D? = nil) async throws -> [CentralSearchHit] {
        var query = ["q": q, "limit": String(limit)]
        if let near { query["lat"] = String(near.latitude); query["lon"] = String(near.longitude) }
        let json = try await get("/search", query)
        let list = (json as? [[String: Any]])
            ?? ((json as? [String: Any])?["results"] as? [[String: Any]])
            ?? ((json as? [String: Any])?["items"] as? [[String: Any]])
            ?? []
        return list.map(Self.hit)
    }

    /// Таксономия POI.
    public func poiMeta() async throws -> [[String: Any]] {
        (try await get("/poi-meta")) as? [[String: Any]] ?? []
    }

    /// Маршрут (Valhalla). mode: car|foot|bike|scooter. Возвращает разобранный JSON.
    public func route(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D,
                      mode: String = "car", avoid: [String] = []) async throws -> [String: Any] {
        var query = [
            "from": "\(from.latitude),\(from.longitude)",
            "to": "\(to.latitude),\(to.longitude)",
            "mode": mode,
        ]
        if !avoid.isEmpty { query["avoid"] = avoid.joined(separator: ",") }
        return (try await get("/route", query)) as? [String: Any] ?? [:]
    }

    /// Изохроны (зоны доступности), GeoJSON.
    public func isochrone(point: CLLocationCoordinate2D, mode: String = "car",
                          minutes: [Int] = [5, 10, 15]) async throws -> [String: Any] {
        let query = [
            "point": "\(point.latitude),\(point.longitude)",
            "mode": mode,
            "minutes": minutes.map(String.init).joined(separator: ","),
        ]
        return (try await get("/isochrone", query)) as? [String: Any] ?? [:]
    }

    // MARK: -

    private func get(_ path: String, _ query: [String: String] = [:]) async throws -> Any {
        var comps = URLComponents(string: config.restBase + path)!
        if !query.isEmpty { comps.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) } }
        var req = URLRequest(url: comps.url!)
        for (k, v) in config.headers { req.setValue(v, forHTTPHeaderField: k) }
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw CentralMapError.badResponse }
        guard (200..<400).contains(http.statusCode) else { throw CentralMapError.http(http.statusCode) }
        return try JSONSerialization.jsonObject(with: data)
    }

    private static func hit(_ j: [String: Any]) -> CentralSearchHit {
        let lat = num(j["lat"] ?? j["latitude"] ?? j["y"])
        let lon = num(j["lon"] ?? j["lng"] ?? j["longitude"] ?? j["x"])
        let coord = (lat != nil && lon != nil) ? CLLocationCoordinate2D(latitude: lat!, longitude: lon!) : nil
        let name = (j["name"] ?? j["label"] ?? j["title"]) as? String ?? ""
        return CentralSearchHit(name: name, coordinate: coord, type: (j["type"] ?? j["class"]) as? String, raw: j)
    }

    private static func num(_ v: Any?) -> Double? {
        if let d = v as? Double { return d }
        if let i = v as? Int { return Double(i) }
        if let s = v as? String { return Double(s) }
        return nil
    }
}
