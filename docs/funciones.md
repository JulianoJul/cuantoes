# Catálogo de Funciones (SPOT)

## Modelos

| Clase | Atributos | Descripción |
|-------|-----------|-------------|
| `TasaBcv` | `usd`, `eur`, `fecha`, `origen` | Modelo de tasa de cambio BCV |
| `TasaBcv.de(moneda)` | `moneda`: 'USD' o 'EUR' | Retorna la tasa para una moneda |
| `TasaBcv.toJson()` / `fromJson()` | — | Serialización JSON |

## Servicios

| Clase/Método | Descripción |
|-------------|-------------|
| `BcvApiService.obtenerTasa()` | Consulta API realtime (USD y EUR) |
| `BcvApiService.obtenerTasaHistorica(fecha)` | Consulta histórico: rango 7 días, tasa más reciente ≤ fecha |
| `BcvScraperService.obtenerTasa()` | Scraping de `bcv.org.ve`, parsea `#dolar` y `#euro` (fallback) |
| `BcvCacheService.obtenerTasa()` | Lee tasa cacheada de SharedPreferences |
| `BcvCacheService.guardarTasa(tasa)` | Guarda tasa en SharedPreferences |
| `TasaRepository.obtenerTasa()` | Orquestador: API → scraping → cache |
| `TasaRepository.obtenerTasaHistorica(fecha)` | Histórico vía API |

## ViewModel

| Clase/Método | Descripción |
|-------------|-------------|
| `ConversorViewmodel.entradaController` | `TextEditingController` vinculado al TextField |
| `ConversorViewmodel.cargarTasa()` | Obtiene tasa (hoy o histórica según fecha) |
| `ConversorViewmodel.setMoneda(moneda)` | Cambia moneda (USD/EUR), recalcula |
| `ConversorViewmodel.seleccionarFecha(fecha)` | Fecha histórica, dispara carga |
| `ConversorViewmodel.volverAHoy()` | Limpia fecha, carga tasa actual |
| `ConversorViewmodel.setEntrada(valor)` | Actualiza entrada y dispara conversión |
| `ConversorViewmodel.toggleDireccion()` | Invierte dirección, resultado → entrada |
| `ConversorViewmodel.convertir()` | Convierte según dirección y moneda |
| `ConversorViewmodel.dispose()` | Libera `entradaController` |

## Enums

| Enum | Valores | Descripción |
|------|---------|-------------|
| `EstadoTasa` | `cargando`, `listo`, `error` | Estado de carga de tasa |
| `ConversionDireccion` | `monedaAVes`, `vesAMoneda` | Dirección de conversión |
