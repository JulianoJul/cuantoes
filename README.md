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
widgets del launcher son `RemoteViews` nativas: uno 4×2 USD/EUR y otro compacto
2×2 configurable entre USD y EUR. WorkManager intenta refrescar cada hora cuando
hay un widget instalado y conectividad; Android puede aplazarlo por ahorro de
batería. La validación de cámara y widgets requiere un dispositivo/launcher real.

## Comandos

```bash
flutter analyze          # análisis estático
flutter test             # pruebas
flutter run              # ejecutar en dispositivo/emulador
flutter build apk --release --target-platform android-arm64 # release ARM64
```

## Docs

Ver `docs/` para la documentación técnica:

- `docs/doc.md` — arquitectura y flujo actual.
- `docs/ai-context.md` — contexto activo y líneas rojas.
- `docs/funciones.md` — catálogo de funciones.
- `docs/decisiones.md` — decisiones de arquitectura.
- `docs/google-stitch-prompt.txt` — prompt para rediseñar la UI/UX en Google Stitch.
