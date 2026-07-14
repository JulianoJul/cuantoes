# Catálogo de Funciones (SPOT)

## Modelos

| Clase | Atributos | Descripción |
|-------|-----------|-------------|
| `TasaBcv` | `usd`, `eur`, `usdt`, `fecha`, `origen` | Modelo de tasa de cambio BCV |
| `TasaBcv.de(moneda)` | `moneda`: 'USD', 'EUR' o 'USDT' | Retorna la tasa para una moneda |
| `TasaBcv.fechaEfectiva` | — | Getter: fecha hábil calculada (≥14h +1 día, salta findes y feriados) |
| `TasaBcv.toJson()` / `fromJson()` | — | Serialización JSON |

## Servicios

| Clase/Método | Descripción |
|-------------|-------------|
| `BcvApiService.obtenerTasa()` | Consulta API realtime (USD y EUR) |
| `BcvApiService.obtenerTasaHistorica(fecha)` | Consulta histórico: rango 7 días, tasa más reciente con `fechaEfectiva ≤ fecha` |
| `BcvApiService.obtenerUsdt()` | Consulta USDT vía `/binance/realtime_ves` |
| `BcvScraperService.obtenerTasa()` | Scraping de `bcv.org.ve`, parsea `#dolar` y `#euro`, extrae "Fecha Valor" del HTML |
| `BcvCacheService.obtenerTasa()` | Lee la tasa cacheada más reciente de SharedPreferences |
| `BcvCacheService.obtenerTasaPorFecha(fecha)` | Lee tasa cacheada para una fecha específica |
| `BcvCacheService.guardarTasa(tasa)` | Guarda tasa en SharedPreferences |
| `TasaRepository.obtenerTasa()` | Orquestador: cache → refrescarTasa |
| `TasaRepository.refrescarTasa()` | Fuerza actualización: API → cache → scraper |
| `TasaRepository.obtenerTasaHistorica(fecha)` | Histórico vía cache → API |
| `TasaRepository.obtenerUsdt()` | USDT vía API |

## ViewModel

| Propiedad/Método | Descripción |
|-----------------|-------------|
| `ConversorViewmodel.entradaController` | `TextEditingController` vinculado al TextField |
| `ConversorViewmodel.variacion` | `double?` — variación porcentual vs día anterior (solo tasa actual) |
| `ConversorViewmodel.cargarTasa()` | Obtiene tasa (histórica con fallback a tasa viva si no hay datos) |
| `ConversorViewmodel.refrescarTasa()` | Fuerza refresco desde API |
| `ConversorViewmodel.setMoneda(moneda)` | Cambia moneda (USD/EUR/USDT), carga USDT si aplica |
| `ConversorViewmodel.seleccionarFecha(fecha)` | Fecha histórica, dispara carga |
| `ConversorViewmodel.volverAHoy()` | Limpia fecha, carga tasa actual |
| `ConversorViewmodel.setEntrada(valor)` | Actualiza entrada y dispara conversión |
| `ConversorViewmodel.toggleDireccion()` | Invierte dirección, resultado (2 decimales) → entrada |
| `ConversorViewmodel.convertir()` | Convierte según dirección y moneda |
| `ConversorViewmodel.dispose()` | Libera `entradaController` |

## Utils

| Clase/Método | Descripción |
|-------------|-------------|
| `esFeriadoBancario(fecha)` | True si la fecha es feriado bancario VE (fijos + móviles) |
| `proximoDiaHabil(fecha)` | Avanza al siguiente día hábil (salta findes y feriados) |

## Enums

| Enum | Valores | Descripción |
|------|---------|-------------|
| `EstadoTasa` | `cargando`, `listo`, `error` | Estado de carga de tasa |
| `ConversionDireccion` | `monedaAVes`, `vesAMoneda` | Dirección de conversión |
