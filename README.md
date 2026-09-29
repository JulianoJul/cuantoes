# cuantoes

App Flutter para conversión USD/EUR/USDT ↔ VES usando la tasa oficial del BCV.

## Arquitectura

La tasa oficial se obtiene mediante proveedores en cascada:

1. **DolarAPI** — fuente principal: `https://ve.dolarapi.com/v1`
2. **BCV Today** — fallback estático: `https://bcv.today/api/v1`
3. **Chitty BCV** — segundo fallback estático: `https://chitty400.github.io/chitty-bcv-api/`

Si los tres proveedores fallan, se usa la última tasa válida guardada en
`shared_preferences`. No se depende del HTML del BCV ni de un scraper local.

## Dependencias principales

- Flutter 3.12+ / Dart 3.12+
- Provider (estado)
- http (APIs JSON)
- shared_preferences (cache)
- intl + flutter_localizations (formato español)
- google_mlkit_text_recognition + image_picker (OCR on-device con selección sobre la foto)
- home_widget + workmanager (snapshot y refresco de widgets nativos Android)

## OCR y widgets Android

El OCR conserva la geometría de ML Kit para seleccionar y copiar texto sobre la
foto, y permite revisar monto, moneda y separadores antes de convertir. Los
widgets del launcher son `RemoteViews` nativas: el 4×2 es un conversor rápido
con cuatro montos configurables, cambio USD/EUR y dirección; el compacto
muestra la conversión de una unidad. WorkManager intenta refrescar las tasas
cada hora cuando hay un widget instalado y conectividad; Android puede
aplazarlo.

## Comandos

```bash
flutter analyze          # análisis estático
flutter test             # pruebas
flutter run              # ejecutar en dispositivo/emulador
flutter build apk --release --target-platform android-arm64 # release ARM64
```

## Documentación

- [`docs/arquitectura.md`](docs/arquitectura.md) — fuente de verdad técnica,
  flujos y catálogo de APIs compartidas.
- [`docs/decisiones.md`](docs/decisiones.md) — historial de decisiones (ADR).
- [`docs/validacion.md`](docs/validacion.md) — evidencia y pendientes en Android.
