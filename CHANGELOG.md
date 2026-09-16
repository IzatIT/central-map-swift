## 0.1.0

- Первый выпуск: SwiftUI `CentralMap` (UIViewRepresentable) и `CentralMapController`
  поверх MapLibre Native iOS (`MLN*`): маркеры (цветные булавки, тап), линии
  (source + line-layer), кластеры (`addCluster`); встроенный стиль над тайлами `map.central.kg`.
- `CentralMapAPI` (async/await): поиск/маршрут/изохрон/poi-meta.
- API-ключ (привязан к сервису `map`): `?key=` для тайлов/шрифтов, `X-API-Key` для REST.
