# AI Context — Cuantoes (Flutter)

## Stack
- **Flutter** (Dart 3.12+): multiplataforma (Android, iOS, web)
- **Provider**: manejo de estado
- **http** + **html**: scraping del BCV
- **shared_preferences**: caché local

## Líneas Rojas
- **Cero hardcodeo**: todo valor variable en constantes con nombre
- **DRY**: no duplicar lógica existente
- **KISS + YAGNI**: solo lo pedido, nada "por si acaso"

## Estado Actual (Julio 2026)
App Flutter para convertir USD↔VES usando la tasa oficial del BCV. Tres capas de obtención de datos:
1. Scraping directo de `bcv.org.ve` (selectores `#dolar`, `#euro`)
2. API fallback: `dolar-vzla.rafnixg.dev/api/v1/bcv/realtime`
3. Cache con SharedPreferences

## Archivos Clave
| Archivo | Para qué |
|---------|----------|
| `lib/main.dart` | Entry point, CuantoesApp |
| `lib/models/tasa_bcv.dart` | Modelo de tasa (USD, EUR, fecha, origen) |
| `lib/services/bcv_scraper_service.dart` | Scraping HTML del BCV |
| `lib/services/bcv_api_service.dart` | API REST fallback |
| `lib/services/bcv_cache_service.dart` | Cache local con SharedPreferences |
| `lib/services/tasa_repository.dart` | Orquestador: scraping → API → cache |
| `lib/viewmodels/conversor_viewmodel.dart` | Estado de UI con ChangeNotifier |
| `lib/screens/conversor_screen.dart` | UI del conversor |
| `pubspec.yaml` | Dependencias del proyecto |

## Comandos
- `flutter analyze` — análisis estático
- `flutter build apk` — build release Android
- `flutter build apk --debug` — build debug
- `flutter test` — pruebas unitarias/widget
