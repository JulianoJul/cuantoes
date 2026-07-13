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
| `BcvScraperService.obtenerTasa()` | Scraping de `bcv.org.ve`, parsea `#dolar` y `#euro` |
| `BcvApiService.obtenerTasa()` | Consulta API `dolar-vzla.rafnixg.dev/api/v1/bcv/realtime` |
| `BcvCacheService.obtenerTasa()` | Lee tasa cacheada de SharedPreferences |
| `BcvCacheService.guardarTasa(tasa)` | Guarda tasa en SharedPreferences |
| `TasaRepository.obtenerTasa()` | Orquestador: scraping → API → cache |

## ViewModel

| Clase/Método | Descripción |
|-------------|-------------|
| `ConversorViewmodel.cargarTasa()` | Obtiene tasa del repositorio |
| `ConversorViewmodel.setEntrada(valor)` | Actualiza entrada y dispara conversión |
| `ConversorViewmodel.toggleDireccion()` | Alterna USD→VES / VES→USD y usa resultado como entrada |
| `ConversorViewmodel.convertir()` | Convierte según dirección actual |

## Enums

| Enum | Valores | Descripción |
|------|---------|-------------|
| `EstadoTasa` | `cargando`, `listo`, `error` | Estado de carga de tasa |
| `ConversionDireccion` | `dolarABolivar`, `bolivarADolar` | Dirección de conversión |
