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
App Flutter para convertir USD/EUR/USDT↔VES usando la tasa oficial del BCV. Soporta conversión bidireccional con tres monedas (USD, EUR, USDT), selector de fecha con calendario para ver tasas históricas (con salto de fines de semana y feriados bancarios venezolanos), y tres capas de obtención de datos:

1. **API REST**: `dolar-vzla.rafnixg.dev/api/v1/bcv/realtime` (principal) + `/api/v1/history/bcv` (histórico) + `/api/v1/binance/realtime_ves` (USDT)
2. **Cache**: SharedPreferences (persistencia offline, búsqueda por clave más reciente)
3. **Scraping**: HTTP directo a `bcv.org.ve` (Dart, selectores `#dolar`, `#euro`) + script Python Selenium Firefox headless (`scrap_bcv.py`) como alternativa cuando BCV bloquea HTTP

Orden de resolución en `TasaRepository`:
- `obtenerTasa()`: cache vigente → refrescarTasa
- `refrescarTasa()`: API → cache → scraper → rethrow
- `obtenerTasaHistorica()`: cache por fecha → API

## Archivos Clave
| Archivo | Para qué |
|---------|----------|
| `lib/main.dart` | Entry point, CuantoesApp, localización es |
| `lib/models/tasa_bcv.dart` | Modelo de tasa (USD, EUR, USDT, fecha, origen) + fechaEfectiva con feriados |
| `lib/utils/feriados_ve.dart` | Feriados bancarios venezolanos (fijos + cálculo Pascua) |
| `lib/services/bcv_api_service.dart` | API REST (realtime + histórico + USDT) |
| `lib/services/bcv_scraper_service.dart` | Scraping HTML del BCV (fallback, extrae "Fecha Valor") |
| `lib/services/bcv_cache_service.dart` | Cache local con SharedPreferences |
| `lib/services/tasa_repository.dart` | Orquestador: cache → API → cache → scraper |
| `lib/viewmodels/conversor_viewmodel.dart` | Estado: moneda, fecha, conversión, TextEditingController |
| `lib/screens/conversor_screen.dart` | UI: tabs USD/EUR/USDT, calendario, conversor, icono $ |
| `scrap_bcv.py` | Scraper Python con Selenium + Firefox headless (alternativa) |
| `pubspec.yaml` | Dependencias del proyecto |

## Comandos
- `flutter analyze` — análisis estático
- `flutter build apk` — build release Android
- `flutter build apk --debug` — build debug
- `flutter test` — pruebas unitarias/widget

## Scraper Python
`scrap_bcv.py` requiere Python 3, selenium, Firefox y geckodriver.
Se ejecuta con: `python3 scrap_bcv.py` (output JSON a stdout).
