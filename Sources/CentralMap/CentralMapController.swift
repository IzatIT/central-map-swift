#if canImport(UIKit)
import CoreLocation
import MapLibre
import UIKit

public extension CLLocationCoordinate2D {
    /// Центр Кыргызстана.
    static var kgCenter: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: 41.3, longitude: 74.6) }
}

/// Аннотация-маркер с цветом и обработчиком тапа.
public final class CentralAnnotation: MLNPointAnnotation {
    public var color: UIColor = .systemBlue
    public var onTap: (() -> Void)?
}

/// Создаёт и обслуживает MLNMapView для central.kg: маркеры (цветные булавки) и линии
/// (через source + line-layer). Используется и в UIKit, и как coordinator в SwiftUI.
public final class CentralMapController: NSObject, MLNMapViewDelegate {

    public let config: CentralMapConfig
    public private(set) weak var mapView: MLNMapView?
    /// Вызывается, когда стиль загружен и можно добавлять оверлеи.
    public var onReady: ((CentralMapController) -> Void)?

    private var styleLoaded = false
    private var pending: [(MLNStyle) -> Void] = []
    private var lineCounter = 0

    public init(config: CentralMapConfig) {
        self.config = config
    }

    /// Создать сконфигурированный MLNMapView.
    /// `layers` — показать ТОЛЬКО эти слои списком (ключи base.* / poi.* / poigroup.*), без панели.
    public func makeMapView(dark: Bool = false,
                            center: CLLocationCoordinate2D = .kgCenter,
                            zoom: Double = 6,
                            layers: [String]? = nil) -> MLNMapView {
        let url = CentralMapStyle.temporaryStyleURL(config, dark: dark, only: layers)
        let mv = MLNMapView(frame: .zero, styleURL: url)
        mv.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        mv.setCenter(center, zoomLevel: zoom, animated: false)
        mv.delegate = self
        self.mapView = mv
        return mv
    }

    // MARK: - Слои

    /// Показать ТОЛЬКО перечисленные слои на живой карте (ключи base.* / poi.* / poigroup.*),
    /// всё остальное скрыть. Менять набор можно в любой момент после загрузки стиля.
    public func showOnlyLayers(_ keys: [String]) {
        guard let style = mapView?.style else { return }
        let vis = CentralMapStyle.visibleLayerIds(for: keys)
        for id in CentralMapStyle.toggleableIds {
            style.layer(withIdentifier: id)?.isVisible = vis.contains(id)
        }
    }

    /// Показать/скрыть один слой по ключу (напр. `base.roads`, `base.poi`).
    public func setLayerVisible(_ key: String, _ visible: Bool) {
        guard let style = mapView?.style else { return }
        for id in CentralMapStyle.layerKeys[key] ?? [] {
            style.layer(withIdentifier: id)?.isVisible = visible
        }
    }

    // MARK: - Оверлеи

    /// Добавить маркер (цветная булавка). onTap — по тапу.
    @discardableResult
    public func addMarker(_ coordinate: CLLocationCoordinate2D,
                          color: UIColor = .systemBlue,
                          title: String? = nil,
                          onTap: (() -> Void)? = nil) -> CentralAnnotation {
        let a = CentralAnnotation()
        a.coordinate = coordinate
        a.title = title
        a.color = color
        a.onTap = onTap
        mapView?.addAnnotation(a)
        return a
    }

    /// Добавить линию. Возвращает id слоя (для возможного удаления).
    @discardableResult
    public func addPolyline(_ coordinates: [CLLocationCoordinate2D],
                            color: UIColor = .systemBlue,
                            width: CGFloat = 4,
                            opacity: CGFloat = 0.85) -> String {
        lineCounter += 1
        let sid = "cmap-line-\(lineCounter)"
        withStyle { style in
            var coords = coordinates
            let feature = MLNPolylineFeature(coordinates: &coords, count: UInt(coords.count))
            let source = MLNShapeSource(identifier: "\(sid)-src", shape: feature, options: nil)
            style.addSource(source)
            let layer = MLNLineStyleLayer(identifier: sid, source: source)
            layer.lineColor = NSExpression(forConstantValue: color)
            layer.lineWidth = NSExpression(forConstantValue: width)
            layer.lineOpacity = NSExpression(forConstantValue: opacity)
            layer.lineCap = NSExpression(forConstantValue: "round")
            layer.lineJoin = NSExpression(forConstantValue: "round")
            style.addLayer(layer)
        }
        return sid
    }

    /// Зона (полигон): контур + заливка ТЕМ ЖЕ цветом, полупрозрачная. Пока только отображение;
    /// freehand-рисование рукой — следующим шагом (UIPanGestureRecognizer + convert(_:toCoordinateFrom:)).
    @discardableResult
    public func addZone(_ coordinates: [CLLocationCoordinate2D],
                        color: UIColor = .systemIndigo,
                        fillOpacity: CGFloat = 0.18,
                        lineWidth: CGFloat = 2.5) -> String {
        lineCounter += 1
        let sid = "cmap-zone-\(lineCounter)"
        withStyle { style in
            var coords = coordinates
            let poly = MLNPolygonFeature(coordinates: &coords, count: UInt(coords.count))
            let source = MLNShapeSource(identifier: "\(sid)-src", shape: poly, options: nil)
            style.addSource(source)
            // заливка тем же цветом, полупрозрачная (карта под зоной видна)
            let fill = MLNFillStyleLayer(identifier: "\(sid)-fill", source: source)
            fill.fillColor = NSExpression(forConstantValue: color)
            fill.fillOpacity = NSExpression(forConstantValue: fillOpacity)
            style.addLayer(fill)
            // контур — линией нужной толщины
            let line = MLNLineStyleLayer(identifier: "\(sid)-line", source: source)
            line.lineColor = NSExpression(forConstantValue: color)
            line.lineWidth = NSExpression(forConstantValue: lineWidth)
            line.lineCap = NSExpression(forConstantValue: "round")
            line.lineJoin = NSExpression(forConstantValue: "round")
            style.addLayer(line)
        }
        return sid
    }

    // ── Freehand-рисование зоны рукой (⚠ проверить на устройстве) ─────────────────
    private var zonePan: UIPanGestureRecognizer?
    private var zoneStroke: [CGPoint] = []
    private var zoneMinDist: CGFloat = 6
    private var onZoneDraw: (([CLLocationCoordinate2D]) -> Void)?

    /// Включить рисование зоны рукой: ОДНИМ пальцем обводишь → отпустил → onChange с кольцом.
    /// ДВУМЯ пальцами карта двигается/зумит как обычно. Показать зону — addZone(ring).
    public func startZoneDraw(minDistance: CGFloat = 6, onChange: @escaping ([CLLocationCoordinate2D]) -> Void) {
        guard let mv = mapView else { return }
        zoneMinDist = minDistance; onZoneDraw = onChange
        let gr = UIPanGestureRecognizer(target: self, action: #selector(handleZonePan(_:)))
        gr.minimumNumberOfTouches = 1
        gr.maximumNumberOfTouches = 1 // рисуем одним пальцем; двумя — жест уходит карте
        // одиночный пан самой карты уступает рисованию, мультитач (pan/zoom) остаётся карте
        for r in mv.gestureRecognizers ?? [] where r is UIPanGestureRecognizer {
            r.require(toFail: gr)
        }
        mv.addGestureRecognizer(gr); zonePan = gr
    }

    /// Выключить рисование зоны (вернуть карте все жесты).
    public func stopZoneDraw() {
        if let gr = zonePan, let mv = mapView { mv.removeGestureRecognizer(gr) }
        zonePan = nil; onZoneDraw = nil; zoneStroke = []
    }

    @objc private func handleZonePan(_ gr: UIPanGestureRecognizer) {
        guard let mv = mapView else { return }
        let p = gr.location(in: mv)
        switch gr.state {
        case .began:
            zoneStroke = [p]
        case .changed:
            if let last = zoneStroke.last, hypot(p.x - last.x, p.y - last.y) < zoneMinDist { return }
            zoneStroke.append(p)
        case .ended, .cancelled:
            let ring = zoneStroke.map { mv.convert($0, toCoordinateFrom: mv) }
            zoneStroke = []
            if ring.count >= 3 { onZoneDraw?(ring) }
        default:
            break
        }
    }

    /// Кластеризация точек: «пузырь» с количеством + одиночные точки (clustered-источник
    /// + circle/symbol слои). Возвращает базовый id (слои: `<id>-clusters/-count/-points`).
    @discardableResult
    public func addCluster(_ coordinates: [CLLocationCoordinate2D],
                           color: UIColor = .systemIndigo,
                           radius: Int = 60,
                           maxZoom: Int = 16,
                           id: String = "cmap-cluster") -> String {
        withStyle { style in
            let feats: [MLNPointFeature] = coordinates.map { c in
                let f = MLNPointFeature(); f.coordinate = c; return f
            }
            let source = MLNShapeSource(identifier: "\(id)-src", features: feats, options: [
                .clustered: true,
                .clusterRadius: radius,
                .maximumZoomLevelForClustering: maxZoom,
            ])
            style.addSource(source)

            let clusters = MLNCircleStyleLayer(identifier: "\(id)-clusters", source: source)
            clusters.predicate = NSPredicate(format: "cluster == YES")
            clusters.circleColor = NSExpression(forConstantValue: color)
            clusters.circleRadius = NSExpression(forConstantValue: 20)
            clusters.circleStrokeColor = NSExpression(forConstantValue: UIColor.white)
            clusters.circleStrokeWidth = NSExpression(forConstantValue: 2)
            style.addLayer(clusters)

            let count = MLNSymbolStyleLayer(identifier: "\(id)-count", source: source)
            count.predicate = NSPredicate(format: "cluster == YES")
            count.text = NSExpression(format: "CAST(point_count, 'NSString')")
            count.textColor = NSExpression(forConstantValue: UIColor.white)
            count.textFontSize = NSExpression(forConstantValue: 12)
            style.addLayer(count)

            let points = MLNCircleStyleLayer(identifier: "\(id)-points", source: source)
            points.predicate = NSPredicate(format: "cluster != YES")
            points.circleColor = NSExpression(forConstantValue: color)
            points.circleRadius = NSExpression(forConstantValue: 6)
            points.circleStrokeColor = NSExpression(forConstantValue: UIColor.white)
            points.circleStrokeWidth = NSExpression(forConstantValue: 2)
            style.addLayer(points)
        }
        return id
    }

    /// Удалить линию по id (если есть).
    public func removePolyline(_ id: String) {
        guard let style = mapView?.style else { return }
        if let layer = style.layer(withIdentifier: id) { style.removeLayer(layer) }
        if let source = style.source(withIdentifier: "\(id)-src") { style.removeSource(source) }
    }

    private func withStyle(_ op: @escaping (MLNStyle) -> Void) {
        if styleLoaded, let style = mapView?.style {
            op(style)
        } else {
            pending.append(op)
        }
    }

    // MARK: - MLNMapViewDelegate

    public func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
        styleLoaded = true
        pending.forEach { $0(style) }
        pending.removeAll()
        onReady?(self)
    }

    public func mapView(_ mapView: MLNMapView, viewFor annotation: MLNAnnotation) -> MLNAnnotationView? {
        guard let a = annotation as? CentralAnnotation else { return nil }
        let id = "cmap-pin"
        let view = mapView.dequeueReusableAnnotationView(withIdentifier: id)
            ?? MLNAnnotationView(reuseIdentifier: id)
        let img = Self.pinImage(color: a.color)
        view.frame = CGRect(origin: .zero, size: img.size)
        view.backgroundColor = .clear
        view.layer.contents = img.cgImage
        view.layer.contentsGravity = .resizeAspect
        // якорь — кончик капли (низ картинки), поэтому смещаем вью вверх
        view.centerOffset = CGVector(dx: 0, dy: -(img.size.height / 2 - 3))
        return view
    }

    /// Красивая метка-капля: цветная «булавка» с белым кольцом, белой точкой и мягкой тенью.
    private static func pinImage(color: UIColor) -> UIImage {
        let w: CGFloat = 30, h: CGFloat = 40
        let cx = w / 2, headR: CGFloat = 12, cy = headR + 3
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        return renderer.image { ctx in
            let c = ctx.cgContext
            // тень под пином
            c.setShadow(offset: CGSize(width: 0, height: 2), blur: 3,
                        color: UIColor.black.withAlphaComponent(0.35).cgColor)
            // хвостик-треугольник (под головой)
            let tail = UIBezierPath()
            tail.move(to: CGPoint(x: cx - 5, y: cy + 8))
            tail.addLine(to: CGPoint(x: cx, y: h - 3))
            tail.addLine(to: CGPoint(x: cx + 5, y: cy + 8))
            tail.close()
            color.setFill(); tail.fill()
            // голова-круг
            let head = UIBezierPath(ovalIn: CGRect(x: cx - headR, y: cy - headR, width: headR * 2, height: headR * 2))
            color.setFill(); head.fill()
            // дальше без тени — кольцо и точка
            c.setShadow(offset: .zero, blur: 0, color: nil)
            UIColor.white.setStroke(); head.lineWidth = 2.4; head.stroke()
            let dot = UIBezierPath(ovalIn: CGRect(x: cx - 3.5, y: cy - 3.5, width: 7, height: 7))
            UIColor.white.setFill(); dot.fill()
        }
    }

    public func mapView(_ mapView: MLNMapView, didSelect annotation: MLNAnnotation) {
        (annotation as? CentralAnnotation)?.onTap?()
    }
}
#endif
