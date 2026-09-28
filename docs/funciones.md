# Catálogo de Funciones (SPOT)

## Modelos

| Clase | Atributos | Descripción |
|-------|-----------|-------------|
| `TasaBcv` | `usd`, `eur`, `usdt`, `fecha`, `origen`, `fechaEfectiva` | Modelo de tasa de cambio BCV |
| `TasaBcv.de(moneda)` | `moneda`: 'USD', 'EUR' o 'USDT' | Retorna la tasa para una moneda |
| `TasaBcv.fechaEfectiva` | — | Campo almacenado de fecha efectiva BCV; su resolución depende del origen de la tasa |
| `TasaBcv.actual()` | — | Factory: crea TasaBcv con fechaEfectiva calculada desde hora actual Venezuela (UTC-4) |
| `TasaBcv.toJson()` / `fromJson()` | — | Serialización JSON |
| `CotizacionUsdt` | `valor`, `fechaEfectiva`, `obtenidaEnUtc`, `origen` | Referencia P2P independiente de USD/EUR oficial |
| `ResultadoTasa` | `tasa`, `modoObtencion`, validación, intento, frescura | Resultado de repositorio con metadatos para UI/widgets |
| `DocumentoOcr` / `RegionOcr` | IDs, texto, bloques/líneas y geometría | Documento de OCR con cada región seleccionable |
| `TransferenciaOcr` | `monto`, `moneda` | Transferencia confirmada desde el flujo OCR al conversor |
| `WidgetSnapshot` | USD/EUR formateados, fecha, fuente, estado | Contrato compartido versionado con RemoteViews Android |

## Servicios

| Clase/Método | Descripción |
|-------------|-------------|
| `BcvProvider` | Contrato común para proveedores de tasa actual, histórico, anterior y USDT opcional |
| `DolarApiService.obtenerTasa()` | Consulta DolarAPI para USD/EUR oficiales y exige una fecha efectiva común |
| `DolarApiService.obtenerTasaHistorica(fecha)` | Consulta los históricos oficiales USD/EUR y retorna la mayor fecha común `≤ fecha` |
| `DolarApiService.obtenerTasaAnterior(fechaLimite)` | Consulta la fecha efectiva común inmediatamente anterior a `fechaLimite` |
| `BcvTodayService.obtenerTasa()` | Consulta `rate.json`, snapshot estático actual de BCV Today |
| `BcvTodayService.obtenerTasaHistorica(fecha)` | Consulta snapshots diarios de BCV Today, retrocediendo si la fecha no existe |
| `ChittyBcvService.obtenerTasa()` | Consulta el dataset actual USD/EUR de Chitty BCV como segundo fallback |
| `ChittyBcvService.obtenerUsdt()` | Consulta el promedio P2P USDT/VES de `p2p_history.json` |
| `BcvCacheService.obtenerTasa()` | Lee la tasa cacheada más reciente cuya `fechaEfectiva` no es posterior a hoy en Venezuela |
| `BcvCacheService.obtenerTasaMasRecienteHasta(fechaLimite)` | Retorna la tasa cacheada más reciente con `fechaEfectiva ≤ fechaLimite` |
| `BcvCacheService.obtenerTasaMasRecienteMenorQue(fechaLimite)` | Retorna la tasa cacheada más reciente con `fechaEfectiva < fechaLimite` |
| `BcvCacheService.obtenerTasaSiguiente(fechaBase)` | Retorna la tasa futura cacheada más cercana a `fechaBase`, sin convertirla en tasa actual |
| `BcvCacheService.obtenerTasaPorFecha(fecha)` | Lee tasa cacheada para una fecha efectiva específica |
| `BcvCacheService.guardarTasa(tasa)` | Guarda tasa en SharedPreferences |
| `BcvCacheService.obtenerUltimaConsulta()` / `registrarConsulta()` | Lee o registra la hora de la última consulta a la API |
| `BcvCacheService.obtenerCotizacionUsdt()` / `guardarCotizacionUsdt()` | Lee y persiste USDT separado de la tasa oficial |
| `BcvCacheService.obtenerUltimaValidacionExitosa()` / `registrarValidacionExitosa()` | Metadatos de frescura para tasas recibidas por red |
| `OcrService.reconocerDocumento(rutaImagen)` | Reconoce texto Latin local y conserva dimensiones, líneas, palabras y geometría |
| `OcrService.documentoDesdeResultado(...)` | Adapta un `RecognizedText` de ML Kit a `DocumentoOcr` |
| `OcrService.reconocerTexto(rutaImagen)` | Compatibilidad: retorna texto plano de la imagen reconocida |
| `HomeWidgetService.publicar(resultado)` | Persiste snapshot versionado y actualiza las instancias RemoteViews |
| `HomeWidgetService.actualizarMonedaCompacta(moneda)` | Persiste USD/EUR y redibuja el widget compacto |
| `WidgetBackgroundRefresh.inicializarYProgramar()` | Inicializa WorkManager y registra refresco horario si hay widgets instalados |
| `WidgetBackgroundRefresh.actualizarProgramacion()` | Programa o cancela el trabajo según widgets detectados en Android |
| `TasaRepository.obtenerTasa()` | Orquestador: cache → refrescarTasa |
| `TasaRepository.obtenerTasaConEstado()` / `refrescarTasaConEstado()` | Retorna tasa con metadatos de fuente, caché y frescura |
| `TasaRepository.refrescarTasa()` | Fuerza actualización: DolarAPI → BCV Today → Chitty BCV → cache; una tasa futura nunca se devuelve como actual |
| `TasaRepository.obtenerTasaHistorica(fecha)` | Histórico: cache exacta → proveedores con histórico → cache previa; conserva la fecha solicitada en la UI |
| `TasaRepository.obtenerTasaAnterior(fechaLimite)` | Obtiene la tasa de la fecha efectiva inmediatamente anterior: cache → proveedores con histórico |
| `TasaRepository.obtenerUsdt()` | Prueba los proveedores en orden hasta obtener un USDT válido |
| `TasaRepository.obtenerTasaSiguiente()` / `existeTasaSiguiente()` | Consulta si hay una tasa efectiva futura cacheada para mostrarla como siguiente disponible |
| `SettingsProvider.isDarkMode` | Getter: indica si el modo oscuro está activo |
| `SettingsProvider.isAutomaticComma` | Getter: indica si el modo de coma automática está activo |
| `SettingsProvider.toggleDarkMode()` | Método: alterna el modo oscuro y lo persiste |
| `SettingsProvider.toggleAutomaticComma()` | Método: alterna el modo de coma automática y lo persiste |
| `SettingsProvider.compactWidgetCurrency` / `setCompactWidgetCurrency()` | Moneda compacta USD/EUR, persistida para ajustes de la app |

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
| `ConversorViewmodel.aplicarMontoEscaneado(monto, moneda)` | Aplica monto OCR, moneda y dirección de entrada en una operación |
| `ConversorViewmodel.onRateAvailable` | Callback opcional para publicar una tasa actualizada en el snapshot Android |

## Utils

| Clase/Método | Descripción |
|-------------|-------------|
| `esFeriadoBancario(fecha)` | True si la fecha es feriado bancario VE (fijos + móviles) |
| `proximoDiaHabil(fecha)` | Avanza al siguiente día hábil (salta findes y feriados) |
| `ahoraVenezuela()` | Hora actual en Venezuela (UTC-4), independiente de la zona del dispositivo |
| `calcularFechaEfectiva(fecha)` | Calcula fecha efectiva BCV: hora ≥ 14 → +1 día → próximo día hábil |
| `fechaEfectivaActual()` | Fecha efectiva actual según hora Venezuela (UTC-4) |
| `AutomaticCommaFormatter` | Formateador de texto que desplaza decimales al escribir (ej: 15 -> 0,15) si está activo |
| `extraerNumeros(texto)` | Extrae apariciones OCR en orden, conserva repetidos/offsets y sugiere moneda contextual |
| `parsearNumero(token)` | Parsea un token numérico en formato venezolano o inglés (`1.234,56`, `848,5458`, `10.50`) |
| `OcrCoordinateMapper.mapearRectangulo(region)` / `aCoordenadasImagen(punto)` | Mapea entre píxeles OCR y el canvas BoxFit.contain |

## Enums

| Enum | Valores | Descripción |
|------|---------|-------------|
| `EstadoTasa` | `cargando`, `listo`, `error` | Estado de carga de tasa |
| `ConversionDireccion` | `monedaAVes`, `vesAMoneda` | Dirección de conversión |
