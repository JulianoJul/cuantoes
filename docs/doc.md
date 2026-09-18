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
│   └── tasa_bcv.dart                # TasaBcv (USD, EUR, USDT, fecha, origen, fechaEfectiva)
├── utils/
│   └── feriados_ve.dart             # Feriados bancarios VE (fijos + Pascua)
├── services/
│   ├── bcv_api_service.dart         # API: realtime + histórico + USDT
│   ├── bcv_scraper_service.dart     # Scraping bcv.org.ve (fallback)
│   ├── bcv_cache_service.dart       # SharedPreferences
│   └── tasa_repository.dart         # cache actual → API → cache → scraper
├── viewmodels/
│   └── conversor_viewmodel.dart     # ChangeNotifier, moneda, fechas, conversión, variación
└── screens/
    └── conversor_screen.dart        # UI: tabs USD/EUR/USDT, calendario, conversor
```

## Flujo de datos

### Tasa actual
```
Usuario → ConversorViewmodel.cargarTasa() → TasaRepository.obtenerTasa()
                                                 ├── cache con fechaEfectiva ≤ hoy VE y vigente? → retorna
                                                 └── refrescarTasa()
                                                     ├── API → guarda cache → retorna si no es futura
                                                     │          └── si es futura, conserva/usa la cache actual
                                                     ├── cache actual → retorna
                                                     └── scraper → guarda cache → retorna
                                                         └── rethrow
```

La cache consultada como tasa actual nunca devuelve una entrada con
`fechaEfectiva` posterior a hoy en Venezuela. Una entrada futura puede permanecer
en cache para informar la siguiente tasa disponible.

### Tasa histórica
```
Usuario → ConversorViewmodel.seleccionarFecha()
             ├── TasaRepository.obtenerTasaHistorica()
             │       ├── cache exacta por fecha efectiva? → retorna
             │       ├── API USD/EUR (ventana 30d, fecha efectiva común ≤ solicitada) → guarda cache
             │       └── cache previa disponible → retorna
             └── _fechaSeleccionada conserva la fecha elegida
```

El calendario permite seleccionar fines de semana y feriados. La tasa aplicada
es la de mayor `fechaEfectiva ≤` la fecha solicitada; la tarjeta muestra esa
fecha como `Tasa aplicada` sin cambiar visualmente la fecha seleccionada.

### Variación porcentual
- `ConversorViewmodel._calcularVariacion()`: compara la tasa actual o histórica con la tasa de la fecha efectiva inmediatamente anterior
- `TasaRepository.obtenerTasaAnterior()` resuelve esa tasa previa desde cache o API
- Visible para USD y EUR con o sin fecha seleccionada; no para USDT
- Se muestra en la UI como "▲ +0.61%" / "▼ -0.20%" junto a la tasa correspondiente

### Fechas y fuentes
- Los timestamps Rafnix sin zona horaria se interpretan como UTC y se convierten a Venezuela (UTC-4) antes de aplicar el corte de las 14:00.
- El histórico consulta USD y EUR por separado, pero solo combina valores de una misma `fechaEfectiva` común.
- `BcvScraperService` usa "Fecha Valor" del HTML como fecha autoritativa cuando está presente; si falta, usa la fecha efectiva actual.

## Scraper Python
`scrap_bcv.py` usa Selenium + Firefox headless para extraer tasas cuando el BCV bloquea HTTP.
Output: JSON con `usd`, `eur`, `fecha_efectiva`, `fecha_valor_bcv`.
Requiere: `pip install selenium`, Firefox, geckodriver.

El script Python es una alternativa manual no integrada en el pipeline Flutter.
El scraper Dart integrado es el que usa "Fecha Valor" como `fechaEfectiva`
autoritativa cuando está disponible.

## Comandos

```bash
flutter analyze          # análisis estático
flutter build apk        # build release Android
flutter build apk --debug # build debug
flutter test             # pruebas
```
