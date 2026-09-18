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

## Estado Actual
App Flutter para convertir USD/EUR/USDT↔VES usando la tasa oficial del BCV. Soporta conversión bidireccional con tres monedas (USD, EUR, USDT), selector de fecha que permite elegir cualquier día del rango, incluidos fines de semana y feriados, y tres capas de obtención de datos. La fecha elegida permanece visible aunque la tasa se resuelva con una fecha efectiva anterior; la tarjeta muestra la `fechaEfectiva` aplicada. La variación funciona para tasas actuales e históricas usando la fecha efectiva inmediatamente anterior, excepto para USDT.

`fechaEfectiva` es un campo almacenado en `TasaBcv`. En la API Rafnix, los timestamps sin zona horaria se tratan como UTC y se convierten a Venezuela (UTC-4) antes de aplicar el corte de las 14:00. En el scraper Dart, "Fecha Valor" es autoritativa cuando está presente.

1. **API REST**: `dolar-vzla.rafnixg.dev/api/v1/bcv/realtime` (principal) + `/api/v1/history/bcv` (histórico) + `/api/v1/binance/realtime_ves` (USDT)
2. **Cache**: SharedPreferences (persistencia offline, búsqueda por fecha efectiva; la tasa actual nunca usa una fecha futura)
3. **Scraping**: HTTP directo a `bcv.org.ve` (Dart, selectores `#dolar`, `#euro`) + script Python Selenium Firefox headless (`scrap_bcv.py`) como alternativa manual cuando BCV bloquea HTTP

Orden de resolución en `TasaRepository`:
- `obtenerTasa()`: cache actual con `fechaEfectiva ≤ hoy` → refrescarTasa; nunca devuelve cache futura
- `refrescarTasa()`: API → cache actual → scraper → rethrow; una respuesta futura no se devuelve como actual
- `obtenerTasaHistorica()`: cache exacta → API que elige la mayor fecha efectiva común de USD/EUR `≤` la solicitada → cache previa
- `obtenerTasaAnterior()`: cache o API para la fecha efectiva común inmediatamente anterior

## Archivos Clave
| Archivo | Para qué |
|---------|----------|
| `lib/main.dart` | Entry point, CuantoesApp, localización es |
| `lib/models/tasa_bcv.dart` | Modelo de tasa (USD, EUR, USDT, fecha, origen, fechaEfectiva) |
| `lib/utils/feriados_ve.dart` | Feriados bancarios venezolanos (fijos + cálculo Pascua), `ahoraVenezuela()`, `fechaEfectivaActual()` |
| `lib/services/bcv_api_service.dart` | API REST, normalización horaria Rafnix, histórico USD/EUR con fecha efectiva común y USDT |
| `lib/services/bcv_scraper_service.dart` | Scraping HTML del BCV (fallback); usa "Fecha Valor" como fecha autoritativa cuando existe |
| `lib/services/bcv_cache_service.dart` | Cache local con SharedPreferences y consultas por límite de fecha efectiva |
| `lib/services/tasa_repository.dart` | Orquestador de cache/API/scraper y protección contra tasas futuras como actuales |
| `lib/viewmodels/conversor_viewmodel.dart` | Estado: moneda, fecha seleccionada, fecha efectiva aplicada, conversión y variación |
| `lib/screens/conversor_screen.dart` | UI: tabs USD/EUR/USDT, calendario, conversor y tarjeta con fecha aplicada |
| `scrap_bcv.py` | Scraper Python con Selenium + Firefox headless (alternativa) |
| `pubspec.yaml` | Dependencias del proyecto |

## Comandos
- `flutter analyze` — análisis estático
- `flutter build apk` — build release Android
- `flutter build apk --debug` — build debug
- `flutter test` — pruebas unitarias/widget

## Scraper Python
`scrap_bcv.py` requiere Python 3, selenium, Firefox y geckodriver.
Se ejecuta con: `python3 scrap_bcv.py` (output JSON a stdout). Es una alternativa
manual no integrada; el scraper Dart integrado aplica la autoridad de "Fecha Valor".
