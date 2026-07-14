# cuantoes

App Flutter para conversión USD/EUR/USDT ↔ VES usando la tasa oficial del BCV.

## Arquitectura

Tres capas de obtención de datos en orden:

1. **API REST** — `dolar-vzla.rafnixg.dev/api/v1` (realtime + histórico)
2. **Cache local** — `shared_preferences` (persistencia offline)
3. **Scraping** — HTTP directo a `bcv.org.ve` + script Python con Selenium/ Firefox headless (`scrap_bcv.py`)

## Dependencias principales

- Flutter 3.12+ / Dart 3.12+
- Provider (estado)
- http + html (scraping)
- shared_preferences (cache)
- intl + flutter_localizations (formato español)

## Comandos

```bash
flutter analyze          # análisis estático
flutter test             # pruebas
flutter run              # ejecutar en dispositivo/emulador
flutter build apk        # build release Android
```

## Docs

Ver `docs/` para documentación técnica, ADRs y catálogo de funciones.
