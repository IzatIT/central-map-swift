import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import CentralMap

/// id слоёв стиля сервера https://map.central.kg/style/{light,dark}.json (одинаковы в обеих темах),
/// снимок 05.10.2026. Обновлять вместе со стилем сайта.
let serverLayerIds: Set<String> = [
    "background", "landcover-builtup", "parking-area", "military", "aeroway-poly", "landcover-green", "landcover-ice",
    "landcover-wetland", "landcover-farm", "landcover-sand", "hillshade", "water-fill", "water-outline",
    "waterway", "water_struct", "road-casing-minor", "road-casing-major", "bridge", "road-fill-minor",
    "barrier", "road-fill-major", "aerialway", "piste", "roadtunnel", "aeroway", "power", "railway", "road-path",
    "boundary-admin", "hl-peak", "peak-circle", "peak-label", "tree", "natpoi-circle", "natpoi-label",
    "hl-water-name", "natural_line", "building-fill", "building-3d", "hl-building-fill", "hl-building-line",
    "road-centerline", "crossing-zebra", "road-oneway", "roadsign-priority", "roadsign-signals", "hl-admin-fill",
    "hl-area-fill", "hl-admin", "hl-area", "hl-rail", "hl-road-glow", "hl-road", "transport-roadside",
    "transport-roadside-label", "poi-z11", "poi-z13", "poi-z14", "poi-z15", "poi-z16", "poi-z17", "poi-z18",
    "place-minor", "hl-waterway-label", "road-label", "place-suburb", "place-village", "place-town", "place-city",
    "admin-hit",
]

/// id прежнего встроенного стиля.
let legacyLayerIds: Set<String> = ["bg", "landcover", "water", "road-casing", "road", "building", "place-labels", "poi"]

/// Адреса стиля и REST; ключ — только заголовком REST.
final class CentralMapConfigTests: XCTestCase {

    func testStyleURLByTheme() {
        let c = CentralMapConfig()
        XCTAssertEqual(c.styleURL().absoluteString, "https://map.central.kg/style/light.json")
        XCTAssertEqual(c.styleURL(dark: false).absoluteString, "https://map.central.kg/style/light.json")
        XCTAssertEqual(c.styleURL(dark: true).absoluteString, "https://map.central.kg/style/dark.json")
    }

    func testOwnServerWithoutTrailingSlashes() {
        let c = CentralMapConfig(apiBase: "https://staging.example.kg///")
        XCTAssertEqual(c.styleURL(dark: true).absoluteString, "https://staging.example.kg/style/dark.json")
        XCTAssertEqual(c.restBase, "https://staging.example.kg/api")
    }

    func testKeyNeverInStyleTilesFontsSprite() {
        let c = CentralMapConfig(apiKey: "ck_map_secret")
        let urls = [c.styleURL().absoluteString, c.styleURL(dark: true).absoluteString,
                    c.legacyTilesTemplate, c.legacyFontsTemplate,
                    c.legacySpriteURL(dark: false), c.legacySpriteURL(dark: true)]
        for u in urls {
            XCTAssertFalse(u.contains("key=") || u.contains("ck_map_secret"), "ключ в адресе: \(u)")
        }
    }

    func testKeyAsHeaderForREST() {
        XCTAssertEqual(CentralMapConfig(apiKey: "ck_map_1").headers, ["X-API-Key": "ck_map_1"])
        XCTAssertEqual(CentralMapConfig(apiKey: "").headers, [:])
        XCTAssertEqual(CentralMapConfig().headers, [:])
        XCTAssertEqual(CentralMapConfig().restBase, "https://map.central.kg/api")
    }

    func testLegacyTemplatesWithoutKey() {
        let c = CentralMapConfig(apiKey: "ck_map_1")
        XCTAssertEqual(c.legacyTilesTemplate, "https://map.central.kg/api/tiles/{z}/{x}/{y}.pbf")
        XCTAssertEqual(c.legacyFontsTemplate, "https://map.central.kg/fonts/{fontstack}/{range}.pbf")
        XCTAssertEqual(c.legacySpriteURL(dark: false), "https://map.central.kg/style/sprite/light")
        let own = CentralMapConfig(tilesURL: "https://tiles.example/{z}/{x}/{y}.pbf?token=t")
        XCTAssertEqual(own.legacyTilesTemplate, "https://tiles.example/{z}/{x}/{y}.pbf?token=t")
    }

    func testDefaultMinZoomIsTwo() {
        XCTAssertEqual(CentralMapConfig.defaultMinZoom, 2)
    }
}

/// Выбор стиля, ключи слоёв (как на сайте) и прежний встроенный стиль.
final class CentralMapStyleTests: XCTestCase {

    // Ключи базовых слоёв сайта (DocsPage BASE_LAYER_KEYS / centralCatalog.ts фронта карты)
    let siteKeys = ["base.buildings", "base.roads", "base.road_labels", "base.road_signs", "base.traffic_signals",
                    "base.rivers", "base.water", "base.green", "base.builtup", "base.terrain", "base.railway",
                    "base.aeroway", "base.parking", "base.power", "base.military", "base.boundaries", "base.places"]

    func testServerStyleByDefault() {
        let c = CentralMapConfig(apiKey: "ck_map_1")
        XCTAssertEqual(CentralMapStyle.resolvedStyleURL(c, dark: false, only: nil, custom: nil).absoluteString,
                       "https://map.central.kg/style/light.json")
        XCTAssertEqual(CentralMapStyle.resolvedStyleURL(c, dark: true, only: ["base.roads"], custom: nil).absoluteString,
                       "https://map.central.kg/style/dark.json")
    }

    func testCustomStyleWins() {
        let c = CentralMapConfig(tilesURL: "https://tiles.example/{z}/{x}/{y}.pbf")
        let mine = URL(string: "https://example.kg/my-style.json")!
        XCTAssertEqual(CentralMapStyle.resolvedStyleURL(c, dark: false, only: nil, custom: mine), mine)
    }

    func testOwnTilesUseLegacyStyleFile() throws {
        let c = CentralMapConfig(apiKey: "ck_map_1", tilesURL: "https://tiles.example/{z}/{x}/{y}.pbf")
        let url = CentralMapStyle.resolvedStyleURL(c, dark: true, only: ["base.roads"], custom: nil)
        XCTAssertTrue(url.isFileURL)
        let style = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        XCTAssertEqual(style["version"] as? Int, 8)
        let central = (style["sources"] as? [String: Any])?["central"] as? [String: Any]
        XCTAssertEqual(central?["tiles"] as? [String], ["https://tiles.example/{z}/{x}/{y}.pbf"])
        XCTAssertEqual(style["glyphs"] as? String, "https://map.central.kg/fonts/{fontstack}/{range}.pbf")
        XCTAssertEqual(style["sprite"] as? String, "https://map.central.kg/style/sprite/dark")
        let text = String(decoding: try Data(contentsOf: url), as: UTF8.self)
        XCTAssertFalse(text.contains("key="))
        // only: ["base.roads"] — остальные слои (кроме фона) скрыты
        let layers = try XCTUnwrap(style["layers"] as? [[String: Any]])
        for l in layers {
            let id = l["id"] as? String ?? ""
            let hidden = (l["layout"] as? [String: Any])?["visibility"] as? String == "none"
            XCTAssertEqual(hidden, !["bg", "road", "road-casing"].contains(id), id)
        }
    }

    func testLegacyJSONLayers() {
        for dark in [false, true] {
            let s = CentralMapStyle.legacyJSON(CentralMapConfig(apiKey: "k"), dark: dark, only: nil)
            let ids = Set((s["layers"] as? [[String: Any]] ?? []).compactMap { $0["id"] as? String })
            XCTAssertEqual(ids, legacyLayerIds)
        }
    }

    func testSiteKeysPointToServerStyleLayers() {
        for k in siteKeys + ["base.poi"] {
            guard let ids = CentralMapStyle.layerKeys[k] else { return XCTFail("нет ключа \(k)") }
            let server = ids.filter { !legacyLayerIds.contains($0) }
            XCTAssertFalse(server.isEmpty, "у \(k) нет слоёв стиля сервера")
            for id in server { XCTAssertTrue(serverLayerIds.contains(id), "\(k) → \(id): такого слоя в стиле сервера нет") }
        }
        for id in CentralMapStyle.poiLayerIds { XCTAssertTrue(serverLayerIds.contains(id), id) }
        for id in CentralMapStyle.toggleableIds {
            XCTAssertTrue(serverLayerIds.contains(id) || legacyLayerIds.contains(id), "лишний id \(id)")
        }
        for id in ["background", "admin-hit", "hl-road", "hl-admin"] { XCTAssertFalse(CentralMapStyle.toggleableIds.contains(id)) }
    }

    func testEveryServerLayerHasKeyOrIsService() {
        let service = serverLayerIds.filter { $0 == "background" || $0 == "admin-hit" || $0.hasPrefix("hl-") }
        let missing = serverLayerIds.subtracting(service).subtracting(CentralMapStyle.toggleableIds)
        XCTAssertEqual(missing, [], "слои стиля сервера без ключа: \(missing)")
    }

    func testVisibleLayerIds() {
        let roads = CentralMapStyle.visibleLayerIds(for: ["base.roads"])
        XCTAssertTrue(roads.isSuperset(of: ["road-fill-major", "road-casing-minor", "bridge", "road", "road-casing"]))
        XCTAssertFalse(roads.contains("water-fill"))

        let poi = Set(CentralMapStyle.poiLayerIds).union(["poi"])
        XCTAssertEqual(CentralMapStyle.visibleLayerIds(for: ["poi.cafe"]), poi)
        XCTAssertEqual(CentralMapStyle.visibleLayerIds(for: ["poigroup.food"]), poi)
        XCTAssertEqual(CentralMapStyle.visibleLayerIds(for: ["base.poi"]), poi)
        XCTAssertEqual(CentralMapStyle.visibleLayerIds(for: ["base.unknown", ""]), [])

        let mix = CentralMapStyle.visibleLayerIds(for: ["base.water", "base.traffic_signals", "poigroup.health"])
        XCTAssertTrue(mix.isSuperset(of: ["water-fill", "roadsign-signals", "poi-z14"]))
        XCTAssertFalse(mix.contains("road-fill-major"))
    }
}

/// Подмена сети для REST-клиента: отдаёт заданный ответ и запоминает запрос.
final class StubProtocol: URLProtocol {
    static var status = 200
    static var body = Data()
    static var lastRequest: URLRequest?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.lastRequest = request
        let resp = HTTPURLResponse(url: request.url!, statusCode: Self.status, httpVersion: "HTTP/1.1",
                                   headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.body)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

/// meta и REST: путь, ключ заголовком, разбор ответа. CentralMapAPI — с iOS 15 / macOS 12 (async URLSession), как и в пакете.
@available(iOS 15.0, macOS 12.0, *)
final class CentralMapAPITests: XCTestCase {

    func testMetaParse() {
        let m = CentralMapMeta(json: ["tilesVersion": "kz3", "minZoom": 2, "maxZoom": 16.0, "dataDate": "2026-10-01"])
        XCTAssertEqual(m.tilesVersion, "kz3")
        XCTAssertEqual(m.minZoom, 2)
        XCTAssertEqual(m.maxZoom, 16)
        XCTAssertEqual(m.raw["dataDate"] as? String, "2026-10-01")
        let empty = CentralMapMeta(json: ["tilesVersion": NSNull()])
        XCTAssertNil(empty.tilesVersion)
        XCTAssertNil(empty.minZoom)
        XCTAssertNil(empty.maxZoom)
    }

    private func api(key: String?) -> CentralMapAPI {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.protocolClasses = [StubProtocol.self]
        return CentralMapAPI(config: CentralMapConfig(apiBase: "https://map.example.kg/", apiKey: key),
                             session: URLSession(configuration: cfg))
    }

    func testMetaRequestUsesHeaderKey() async throws {
        StubProtocol.status = 200
        StubProtocol.body = Data(#"{"tilesVersion":"kz3","minZoom":2,"maxZoom":16}"#.utf8)
        let meta = try await api(key: "ck_map_test").meta()
        XCTAssertEqual(meta.tilesVersion, "kz3")
        XCTAssertEqual(meta.minZoom, 2)
        let req = try XCTUnwrap(StubProtocol.lastRequest)
        XCTAssertEqual(req.url?.absoluteString, "https://map.example.kg/api/meta")
        XCTAssertEqual(req.value(forHTTPHeaderField: "X-API-Key"), "ck_map_test")
    }

    func testSearchKeyOnlyInHeader() async throws {
        StubProtocol.status = 200
        StubProtocol.body = Data(#"{"results":[{"name":"Ала-Тоо","lat":42.8765,"lon":74.6037,"class":"square"}]}"#.utf8)
        let hits = try await api(key: "ck_map_test").search("Ала-Тоо", limit: 5)
        XCTAssertEqual(hits.count, 1)
        XCTAssertEqual(hits.first?.name, "Ала-Тоо")
        XCTAssertEqual(hits.first?.type, "square")
        XCTAssertEqual(hits.first?.coordinate?.latitude ?? 0, 42.8765, accuracy: 1e-9)
        let req = try XCTUnwrap(StubProtocol.lastRequest)
        let comps = try XCTUnwrap(URLComponents(url: req.url!, resolvingAgainstBaseURL: false))
        XCTAssertEqual(comps.path, "/api/search")
        XCTAssertEqual(Set(comps.queryItems ?? []), [URLQueryItem(name: "q", value: "Ала-Тоо"), URLQueryItem(name: "limit", value: "5")])
        XCTAssertFalse(req.url!.absoluteString.contains("key="))
        XCTAssertEqual(req.value(forHTTPHeaderField: "X-API-Key"), "ck_map_test")
    }

    func testHTTPErrorThrows() async {
        StubProtocol.status = 401
        StubProtocol.body = Data(#"{"error":"api_key_missing"}"#.utf8)
        do {
            _ = try await api(key: nil).meta()
            XCTFail("ожидалась ошибка 401")
        } catch CentralMapError.http(let code) {
            XCTAssertEqual(code, 401)
            XCTAssertNil(StubProtocol.lastRequest?.value(forHTTPHeaderField: "X-API-Key"))
        } catch {
            XCTFail("не та ошибка: \(error)")
        }
    }
}
