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

## Comandos

```bash
flutter analyze          # análisis estático
flutter test             # pruebas
flutter run              # ejecutar en dispositivo/emulador
flutter build apk        # build release Android
```

## Docs

Ver `docs/` para la documentación técnica:

- `docs/doc.md` — arquitectura y flujo actual.
- `docs/funciones.md` — catálogo de funciones.
- `docs/decisiones.md` — decisiones de arquitectura.
- `docs/google-stitch-prompt.txt` — prompt para rediseñar la UI/UX en Google Stitch.
