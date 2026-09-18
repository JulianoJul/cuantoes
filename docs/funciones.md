# Catálogo de Funciones (SPOT)

## Modelos

| Clase | Atributos | Descripción |
|-------|-----------|-------------|
| `TasaBcv` | `usd`, `eur`, `usdt`, `fecha`, `origen`, `fechaEfectiva` | Modelo de tasa de cambio BCV |
| `TasaBcv.de(moneda)` | `moneda`: 'USD', 'EUR' o 'USDT' | Retorna la tasa para una moneda |
| `TasaBcv.fechaEfectiva` | — | Campo almacenado de fecha efectiva BCV; su resolución depende del origen de la tasa |
| `TasaBcv.actual()` | — | Factory: crea TasaBcv con fechaEfectiva calculada desde hora actual Venezuela (UTC-4) |
| `TasaBcv.toJson()` / `fromJson()` | — | Serialización JSON |

## Servicios

| Clase/Método | Descripción |
|-------------|-------------|
| `BcvApiService.obtenerTasa()` | Consulta API realtime (USD y EUR), normaliza timestamps Rafnix sin zona como UTC y exige una fecha efectiva común |
| `BcvApiService.obtenerTasaHistorica(fecha)` | Consulta histórico en la ventana `[fecha-30 días, fecha+1 día]`; agrupa USD/EUR por fecha efectiva común y retorna la mayor `fechaEfectiva ≤ fecha` |
| `BcvApiService.obtenerTasaAnterior(fechaLimite)` | Consulta el histórico y retorna la tasa USD/EUR de la fecha efectiva común inmediatamente anterior a `fechaLimite` |
| `BcvApiService.obtenerUsdt()` | Consulta USDT vía `/binance/realtime_ves` |
| `BcvScraperService.obtenerTasa()` | Scraping de `bcv.org.ve`, parsea `#dolar` y `#euro`; si existe "Fecha Valor", la usa como `fecha` y `fechaEfectiva` autoritativas |
| `BcvCacheService.obtenerTasa()` | Lee la tasa cacheada más reciente cuya `fechaEfectiva` no es posterior a hoy en Venezuela |
| `BcvCacheService.obtenerTasaMasRecienteHasta(fechaLimite)` | Retorna la tasa cacheada más reciente con `fechaEfectiva ≤ fechaLimite` |
| `BcvCacheService.obtenerTasaMasRecienteMenorQue(fechaLimite)` | Retorna la tasa cacheada más reciente con `fechaEfectiva < fechaLimite` |
| `BcvCacheService.obtenerTasaSiguiente(fechaBase)` | Retorna la tasa futura cacheada más cercana a `fechaBase`, sin convertirla en tasa actual |
| `BcvCacheService.obtenerTasaPorFecha(fecha)` | Lee tasa cacheada para una fecha efectiva específica |
| `BcvCacheService.guardarTasa(tasa)` | Guarda tasa en SharedPreferences |
| `BcvCacheService.obtenerUltimaConsulta()` / `registrarConsulta()` | Lee o registra la hora de la última consulta a la API |
| `OcrService.reconocerTexto(rutaImagen)` | Reconoce texto de una imagen con ML Kit (script Latin, on-device) |
| `TasaRepository.obtenerTasa()` | Orquestador: cache → refrescarTasa |
| `TasaRepository.refrescarTasa()` | Fuerza actualización: API → cache → scraper; una tasa futura nunca se devuelve como actual |
| `TasaRepository.obtenerTasaHistorica(fecha)` | Histórico: cache exacta → API con mayor fecha efectiva `≤ fecha` → devuelve la mayor fecha efectiva entre la API y la cache previa; conserva la fecha solicitada en la UI |
| `TasaRepository.obtenerTasaAnterior(fechaLimite)` | Obtiene la tasa de la fecha efectiva inmediatamente anterior: cache exacta → API → mayor fecha efectiva entre la API y la cache previa |
| `TasaRepository.obtenerUsdt()` | USDT vía API |
| `TasaRepository.obtenerTasaSiguiente()` / `existeTasaSiguiente()` | Consulta si hay una tasa efectiva futura cacheada para mostrarla como siguiente disponible |
| `SettingsProvider.isDarkMode` | Getter: indica si el modo oscuro está activo |
| `SettingsProvider.isAutomaticComma` | Getter: indica si el modo de coma automática está activo |
| `SettingsProvider.toggleDarkMode()` | Método: alterna el modo oscuro y lo persiste |
| `SettingsProvider.toggleAutomaticComma()` | Método: alterna el modo de coma automática y lo persiste |

## ViewModel

| Propiedad/Método | Descripción |
|-----------------|-------------|
| `ConversorViewmodel.entradaController` | `TextEditingController` vinculado al TextField |
| `ConversorViewmodel.variacion` | `double?` — variación porcentual de la tasa actual o histórica frente a la fecha efectiva inmediatamente anterior; no aplica a USDT |
| `ConversorViewmodel.fechaEfectivaAplicada` | Fecha efectiva de la tasa que se está mostrando en la tarjeta |
| `ConversorViewmodel.fechaTasaSiguiente` | `DateTime?` — fecha efectiva de la próxima tasa ya publicada, o `null` si aún no existe |
| `ConversorViewmodel.fechaMaximaSeleccionable` | Mayor fecha elegible en el calendario: `fechaTasaSiguiente` o hoy en Venezuela |
| `ConversorViewmodel.cargarTasa()` | Obtiene la tasa actual o histórica; conserva la fecha seleccionada aunque se aplique una tasa anterior |
| `ConversorViewmodel.refrescarTasa()` | Fuerza refresco desde API |
| `ConversorViewmodel.setMoneda(moneda)` | Cambia moneda (USD/EUR/USDT), carga USDT si aplica |
| `ConversorViewmodel.seleccionarFecha(fecha)` | Acepta cualquier fecha disponible en el calendario, incluidos fines de semana y feriados, y dispara la carga histórica |
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
| `ahoraVenezuela()` | Hora actual en Venezuela (UTC-4), independiente de la zona del dispositivo |
| `calcularFechaEfectiva(fecha)` | Calcula fecha efectiva BCV: hora ≥ 14 → +1 día → próximo día hábil |
| `fechaEfectivaActual()` | Fecha efectiva actual según hora Venezuela (UTC-4) |
| `AutomaticCommaFormatter` | Formateador de texto que desplaza decimales al escribir (ej: 15 -> 0,15) si está activo |
| `extraerNumeros(texto)` | Extrae números de un texto OCR sin repetidos, con su token original |
| `parsearNumero(token)` | Parsea un token numérico en formato venezolano o inglés (`1.234,56`, `848,5458`, `10.50`) |

## Enums

| Enum | Valores | Descripción |
|------|---------|-------------|
| `EstadoTasa` | `cargando`, `listo`, `error` | Estado de carga de tasa |
| `ConversionDireccion` | `monedaAVes`, `vesAMoneda` | Dirección de conversión |
