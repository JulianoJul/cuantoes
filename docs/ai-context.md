# AI Context — Cuantoes (Flutter)

## Stack
- **Flutter** (Dart 3.12+): multiplataforma (Android, iOS, web)
- **Provider**: manejo de estado
- **http** + **html**: scraping del BCV (fallback)
- **shared_preferences**: caché local
- **intl** + **flutter_localizations**: formato y localización (es)

## Líneas Rojas
- **Cero hardcodeo**: todo valor variable en constantes con nombre
- **DRY**: no duplicar lógica existente
- **KISS + YAGNI**: solo lo pedido, nada "por si acaso"

## Estado Actual (Julio 2026)
App Flutter para convertir USD/EUR↔VES usando la tasa oficial del BCV. Soporta conversión bidireccional con ambas monedas (USD y EUR), selector de fecha con calendario para ver tasas históricas, y tres capas de obtención de datos:
1. API REST: `dolar-vzla.rafnixg.dev/api/v1/bcv/realtime` (principal) + `/api/v1/history/bcv` (histórico)
2. Scraping directo de `bcv.org.ve` (fallback, selectores `#dolar`, `#euro`)
3. Cache con SharedPreferences (última tasa guardada)

## Archivos Clave
| Archivo | Para qué |
|---------|----------|
| `lib/main.dart` | Entry point, CuantoesApp, localización es |
| `lib/models/tasa_bcv.dart` | Modelo de tasa (USD, EUR, fecha, origen) |
| `lib/services/bcv_api_service.dart` | API REST (realtime + histórico) |
| `lib/services/bcv_scraper_service.dart` | Scraping HTML del BCV (fallback) |
| `lib/services/bcv_cache_service.dart` | Cache local con SharedPreferences |
| `lib/services/tasa_repository.dart` | Orquestador: API → scraping → cache |
| `lib/viewmodels/conversor_viewmodel.dart` | Estado: moneda, fecha, conversión, TextEditingController |
| `lib/screens/conversor_screen.dart` | UI: tabs USD/EUR, calendario, conversor, icono $ |
| `pubspec.yaml` | Dependencias del proyecto |

## Comandos
- `flutter analyze` — análisis estático
- `flutter build apk` — build release Android
- `flutter build apk --debug` — build debug
- `flutter test` — pruebas unitarias/widget
