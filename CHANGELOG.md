## 0.2.0

- Стиль карты — с сервера, тот же, что у сайта: `https://map.central.kg/style/{light,dark}.json`
  по теме `dark`. Значки, шрифты, рельеф и версия тайлов приходят вместе со стилем — правки сайта
  доходят до приложений без обновления пакета. Свой встроенный стиль больше не используется.
- Ключ — только для REST (`X-API-Key`): к адресам тайлов и шрифтов `?key=` больше не добавляется
  (они открыты, ключ в адресе дробил кэш CDN).
- `makeMapView(...)` и SwiftUI `CentralMap(...)`: `minZoom` (по умолчанию 2 —
  `CentralMapConfig.defaultMinZoom`, тайлы есть с z2) и `styleURL` (свой стиль); у SwiftUI-карты —
  `layers`.
- `CentralMapConfig.styleURL(dark:)` — адрес стиля сервера.
- `CentralMapAPI.meta()` — `GET /api/meta`: версия тайлов, масштабы, страны (`CentralMapMeta`).
- Слои списком: те же ключи, что на сайте — 17 базовых `base.*`; `poi.*`, `poigroup.*` и `base.poi`
  включают все слои мест. Набор `layers` применяется после загрузки стиля.
- Число в кластере (`addCluster`) — шрифтом Noto Sans Regular: шрифта MapLibre по умолчанию на сервере
  нет, и число не рисовалось.
- Устарело (работает, уберём в 1.0): `CentralMapStyle.json`, `CentralMapStyle.temporaryStyleURL`,
  `CentralMapConfig.tilesTemplate`, `fontsTemplate`, `spriteTemplate`, `tilesURL`. Если задан `tilesURL`
  (свои тайлы), карта строится прежним встроенным стилем над ними, как в 0.1.
- Совместимость: код под 0.1 собирается без правок.
- Тесты (`Tests/CentralMapTests`) и CI: сборка и тесты на iOS Simulator (GitHub Actions, macOS).

## 0.1.1

- Карта без вотермарки MapLibre и кнопки (i) с атрибуцией — чистые углы под свой UI.

## 0.1.0

- Первый выпуск: SwiftUI `CentralMap` (UIViewRepresentable) и `CentralMapController`
  поверх MapLibre Native iOS (`MLN*`): маркеры (цветные булавки, тап), линии
  (source + line-layer), кластеры (`addCluster`); встроенный стиль над тайлами `map.central.kg`.
- `CentralMapAPI` (async/await): поиск/маршрут/изохрон/poi-meta.
- API-ключ (привязан к сервису `map`): `?key=` для тайлов/шрифтов, `X-API-Key` для REST.
