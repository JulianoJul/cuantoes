# Cuantoes — Documentación

## Stack

| Capa | Tecnología |
|------|-----------|
| Framework | Flutter (Dart 3.12+) |
| Estado | Provider + ChangeNotifier |
| HTTP | http + html (scraping) |
| Cache | shared_preferences |
| Formato | intl |

## Arquitectura

```
lib/
├── main.dart                        # CuantoesApp, MaterialApp
├── models/
│   └── tasa_bcv.dart                # TasaBcv (USD, EUR, fecha, origen)
├── services/
│   ├── bcv_scraper_service.dart     # Scraping bcv.org.ve
│   ├── bcv_api_service.dart         # API dolar-vzla.rafnixg.dev
│   ├── bcv_cache_service.dart       # SharedPreferences
│   └── tasa_repository.dart         # scraping → API → cache
├── viewmodels/
│   └── conversor_viewmodel.dart     # ChangeNotifier, lógica conversión
└── screens/
    └── conversor_screen.dart        # UI conversor
```

## Flujo de datos

```
Usuario → ConversorViewmodel → TasaRepository
                                    ├── BcvScraperService (bcv.org.ve)
                                    ├── BcvApiService (API fallback)
                                    └── BcvCacheService (SharedPreferences)
```

## Comandos

```bash
flutter analyze          # análisis estático
flutter build apk        # build release Android
flutter build apk --debug # build debug
flutter test             # pruebas
```
