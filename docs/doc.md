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
| Scraping Python | selenium + Firefox headless (alternativa) |

## Arquitectura

```
lib/
├── main.dart                        # CuantoesApp, MaterialApp, locale es
├── models/
│   └── tasa_bcv.dart                # TasaBcv (USD, EUR, USDT, fecha, origen)
├── utils/
│   └── feriados_ve.dart             # Feriados bancarios VE (fijos + Pascua)
├── services/
│   ├── bcv_api_service.dart         # API: realtime + histórico + USDT
│   ├── bcv_scraper_service.dart     # Scraping bcv.org.ve (fallback)
│   ├── bcv_cache_service.dart       # SharedPreferences
│   └── tasa_repository.dart         # cache → API → cache → scraper
├── viewmodels/
│   └── conversor_viewmodel.dart     # ChangeNotifier, moneda, fecha, conversión
└── screens/
    └── conversor_screen.dart        # UI: tabs USD/EUR/USDT, calendario, conversor
```

## Flujo de datos

### Tasa actual
```
Usuario → ConversorViewmodel.cargarTasa() → TasaRepository.obtenerTasa()
                                                ├── cache vigente? → retorna
                                                └── refrescarTasa()
                                                    ├── API → guarda cache → retorna
                                                    ├── cache → retorna
                                                    └── scraper → guarda cache → retorna
                                                        └── rethrow
```

### Tasa histórica
```
Usuario → ConversorViewmodel.seleccionarFecha()
            ├── TasaRepository.obtenerTasaHistorica()
            │       ├── cache por fecha? → retorna
            │       └── API (rango 7d, filter fechaEfectiva) → guarda cache
            └── si no hay datos → TasaRepository.obtenerTasa() (tasa viva)
                └── _fechaSeleccionada se actualiza a la fechaEfectiva real
```

### Variación porcentual
- `ConversorViewmodel._calcularVariacion()`: compara tasa actual vs día anterior
- Solo visible para tasa actual (sin fecha seleccionada), no para USDT
- Se muestra en la UI como "▲ +0.61%" / "▼ -0.20%" junto a la tasa correspondiente

## Scraper Python
`scrap_bcv.py` usa Selenium + Firefox headless para extraer tasas cuando el BCV bloquea HTTP.
Output: JSON con `usd`, `eur`, `fecha_efectiva`, `fecha_valor_bcv`.
Requiere: `pip install selenium`, Firefox, geckodriver.

## Comandos

```bash
flutter analyze          # análisis estático
flutter build apk        # build release Android
flutter build apk --debug # build debug
flutter test             # pruebas
```
