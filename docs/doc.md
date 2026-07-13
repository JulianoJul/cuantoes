# Cuantoes — Documentación

## Stack

| Capa | Tecnología |
|------|-----------|
| Framework | Flutter (Dart 3.12+) |
| Estado | Provider + ChangeNotifier |
| HTTP | http + html (scraping) |
| Cache | shared_preferences |
| Formato | intl |
| Localización | flutter_localizations (es) |

## Arquitectura

```
lib/
├── main.dart                        # CuantoesApp, MaterialApp, locale es
├── models/
│   └── tasa_bcv.dart                # TasaBcv (USD, EUR, fecha, origen)
├── services/
│   ├── bcv_api_service.dart         # API: realtime + histórico
│   ├── bcv_scraper_service.dart     # Scraping bcv.org.ve (fallback)
│   ├── bcv_cache_service.dart       # SharedPreferences
│   └── tasa_repository.dart         # API → scraping → cache
├── viewmodels/
│   └── conversor_viewmodel.dart     # ChangeNotifier, moneda, fecha, conversión
└── screens/
    └── conversor_screen.dart        # UI: tabs USD/EUR, calendario, conversor
```

## Flujo de datos

```
Usuario → ConversorViewmodel → TasaRepository
                                    ├── BcvApiService (principal)
                                    │   ├── obtenerTasa() → /bcv/realtime
                                    │   └── obtenerTasaHistorica(fecha) → /history/bcv
                                    ├── BcvScraperService (fallback)
                                    └── BcvCacheService (último recurso)
```

## Comandos

```bash
flutter analyze          # análisis estático
flutter build apk        # build release Android
flutter build apk --debug # build debug
flutter test             # pruebas
```
