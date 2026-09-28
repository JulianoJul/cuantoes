# Cuantoes — Auditoría y plan de implementación para Luna

**Fecha:** 27 de septiembre de 2026.  
**Base revisada:** commit `27ca138`, más los diseños locales de `stitch/`.  
**Entregable original:** diagnóstico y planificación sobre el commit indicado. La sección de estado siguiente registra la implementación posterior; los hallazgos y criterios inferiores siguen describiendo la línea base auditada.

## Estado de implementación — 27 de septiembre de 2026

| Fase | Estado | Evidencia / pendiente real |
|---|---|---|
| Tasas, fechas, fallbacks y caché | Implementación integrada | `TasaBcv`, `ResultadoTasa`, repositorio y caché; cubierto por pruebas de proveedores y repositorio. Revisar matriz completa de calendarios/feriados con reloj inyectado sigue pendiente. |
| USDT | Implementación integrada | `CotizacionUsdt` independiente, persistencia, TTL y errores propios. |
| UI Stitch/adaptable | Implementación integrada | Claro/oscuro, scroll, tarjeta de estado, fechas, atajos, copia y feedback. Prueba automatizada de 360×640 con teclado; falta verificación manual a texto 200%/landscape. |
| OCR estructurado y selección | Implementación integrada, dispositivo pendiente | Conserva regiones/polígonos, muestra la imagen, permite selección/copia y revisión de monto/divisa; tests para mapping y transferencia. Foto física, EXIF, gestos con zoom y permisos deben validarse en Android real. |
| Widgets Android | Implementación integrada, launcher pendiente | AppWidgetProvider/RemoteViews 4×2 y compacto 2×2, snapshot versionado y WorkManager horario condicionado a instancias detectadas. Falta comprobar añadir/quitar, reinicio, Doze, offline y refresco con app cerrada en launcher real. La moneda compacta se configura globalmente desde Ajustes, no por instancia. |
| Validación local | Completada en este checkout | `flutter analyze --no-pub` sin incidencias; **55 pruebas** aprobadas; APK Release de 34,3 MB con ABI nativa solo `arm64-v8a`. AAPT confirma ambos receivers y no informa `application-debuggable`. Falta prueba end-to-end física. Release conserva firma debug y no está listo para distribución pública. |

La actualización de fondo es de mejor esfuerzo: Android decide cuándo ejecutar WorkManager y puede aplazarlo por batería/Doze. El intervalo programado es 60 minutos, no una garantía de actualización exacta.

El build actual avisa que `home_widget` y `workmanager_android` aplican Kotlin Gradle Plugin explícito; hoy compilan, pero Flutter advierte que versiones futuras migrarán a Kotlin integrado.

Las casillas de las fases siguientes permanecen como lista de aceptación detallada: una función integrada no se considera validada en hardware hasta completar los ensayos de dispositivo indicados arriba.

## 1. Resumen ejecutivo

La base del proyecto es aprovechable: Flutter/Material 3, Provider, repositorio de tasas, proveedores intercambiables y caché local. Recomiendo una evolución incremental de esa estructura.

El orden de trabajo recomendado es:

1. **Corregir exactitud y estados de datos:** tasas inválidas, USDT, frescura de caché, fechas y fallbacks.
2. **Preparar componentes y metadatos:** necesarios para que la nueva UI y los widgets muestren información real.
3. **Adaptar Stitch a Flutter:** principal clara/oscura, estados offline e histórico y diseño adaptable al teclado.
4. **Implementar OCR con selección sobre la foto:** conservar geometría de ML Kit, mostrar la imagen, seleccionar texto y transferir un monto explícito.
5. **Implementar widgets del inicio de Android:** primero USD/EUR desde un snapshot compartido; después actualización en segundo plano y versión compacta configurable.

### Hallazgos principales

- El conversor puede producir **`Infinity` al dividir entre una tasa USDT no disponible**.
- Una caché muy antigua puede considerarse vigente únicamente porque hoy es feriado o fin de semana.
- Algunos retornos anticipados impiden consultar un fallback con datos más recientes.
- La igualdad de USD/EUR puede hacer que se descarte una próxima tasa con fecha explícita válida.
- USDT carece de persistencia y metadatos propios; se mezcla con la fecha y fuente de USD/EUR.
- El OCR conserva texto plano, pero pierde las posiciones necesarias para seleccionar sobre la imagen.
- El parser OCR puede convertir **`10 20` en `1020`** cuando se usa el texto completo.
- La pantalla principal presenta desbordamientos en un teléfono de 360 × 640 con teclado abierto.
- Los widgets del launcher todavía no tienen implementación nativa.
- Stitch aporta una buena dirección visual, pero contiene datos, capacidades y textos simulados que deben adaptarse.

**Prioridades usadas:** P1 = exactitud, fiabilidad o requisito central; P2 = mantenibilidad, rendimiento o mejora de experiencia; P3 = pulido posterior. No se identificó un incidente P0 en esta revisión.

## 2. Alcance y evidencia

### 2.1 Qué se revisó

- Los **17 archivos Dart de `lib/`**, aproximadamente **2.600 líneas**.
- Los **8 archivos de pruebas** existentes.
- Configuración Android, manifiesto fuente y manifiesto fusionado disponible, actividad Kotlin, dependencias, reglas R8 y Makefile.
- README, documentación técnica y `.clinerules`.
- Las **5 capturas** de Stitch, sus HTML y `stitch/sovereign_exchange/DESIGN.md`.
- Respuestas públicas puntuales de los proveedores y documentación de ML Kit, cámara, image picker, home_widget y WorkManager.

Las referencias `archivo:línea` corresponden a la base auditada; cambiarán al implementar.

### 2.2 Validación realizada

| Comprobación | Resultado |
|---|---|
| Entorno | Flutter 3.47.5, Dart 3.13.4 |
| `flutter analyze --no-pub` | Sin incidencias |
| `flutter test --no-pub --reporter expanded` | 42 pruebas aprobadas |
| Comprobaciones temporales adicionales, fuera del repositorio | 10 casos confirmaron comportamientos descritos abajo |
| Inspección del APK que ya existía | Contiene `arm64-v8a`, `armeabi-v7a` y `x86_64` |
| Pruebas de cámara/ML Kit/launcher en dispositivo físico | Pendientes para la implementación |

Las comprobaciones temporales **afirmaban la existencia de las anomalías**, no su corrección. El último caso confirmó desbordamientos de 253 px abajo y de 16/42 px a la derecha. La primera ejecución de ese caso necesitó ajustar la captura de errores del propio ensayo; la repetición confirmó los desbordamientos.

No se generó un APK nuevo en esta auditoría. El APK disponible no acredita el filtro ARM64 del código actual: su contenido todavía incluye otras ABI.

### 2.3 Observación puntual de proveedores

Respuestas observadas el 27/09/2026; son evidencia de contrato en ese momento, no disponibilidad garantizada:

| Fuente | Observación |
|---|---|
| DolarAPI actual USD/EUR | HTTP 200; USD `855.6625`, EUR `972.648677`; `fechaActualizacion = 2026-09-25T00:00:00-04:00` |
| DolarAPI históricos USD/EUR | HTTP 200; 898 registros en cada lista; fechas desde `2023-01-03` hasta `2026-09-28` |
| BCV Today `rate.json` | `effective_date = 2026-09-25`, `date = 2026-09-27`, `updated_at = 2026-09-24T21:38:56.194100+00:00` |
| Chitty `latest.json` | Cotización actual y objeto `adelantada`, con `aplica_desde = 2026-09-28` |
| Chitty `p2p_history.json` | 122 fechas; última observada `2026-09-27`; `ves.tasa_final_promedio = 967.19` |

Esto confirma dos detalles importantes:

- **Fecha de publicación/actualización y fecha efectiva son conceptos distintos.** BCV Today lo demuestra explícitamente.
- **Existen datos de la próxima tasa que la implementación no aprovecha:** el objeto `adelantada` de Chitty y las fechas futuras comunes del histórico de DolarAPI.

## 3. Estructura actual y dirección recomendada

### 3.1 Flujo actual

```text
main.dart
  ├─ FeriadosService.cargarCache()
  └─ SettingsProvider → MaterialApp
       └─ ConversorScreen → ConversorViewmodel
            ├─ TasaRepository → DolarAPI / BCV Today / Chitty
            │                    └─ BcvCacheService → SharedPreferences
            └─ estado de entrada, moneda, fecha, variación y conversión

ConversorScreen
  └─ cámara / galería → OcrService → String → _OcrDialog → entrada
```

### 3.2 Lo que funciona bien

- `BcvProvider` permite sustituir proveedores y probar fallbacks sin depender de HTTP real.
- USD y EUR se emparejan por fecha común en DolarAPI.
- La consulta actual intenta excluir tasas futuras y el histórico conserva la fecha solicitada.
- `_refreshEnCurso` evita refrescos duplicados dentro de una instancia del repositorio.
- El ViewModel usa generaciones para descartar algunas respuestas fuera de orden.
- El reconocedor OCR se cierra mediante `finally`.
- La separación entre proveedor, repositorio y pantalla ya existe; puede ampliarse sin cambiar de framework de estado.

### 3.3 Puntos estructurales a mejorar

| ID | Prioridad | Evidencia | Recomendación |
|---|---|---|---|
| ARC-01 | P2 | `lib/screens/conversor_screen.dart`, 730 líneas: layout, calendario, OCR, navegación, parser de entrada, portapapeles y ajustes | Extraer componentes y un flujo OCR propio. Mantener la pantalla como composición y coordinación de acciones. |
| ARC-02 | P2 | `conversor_viewmodel.dart:72-223`: duplicación entre carga y refresco | Compartir la aplicación de resultados y separar carga inicial, refresco y consulta histórica. |
| ARC-03 | P2 | Fechas y clientes se construyen directamente en varias capas; la pantalla crea ViewModel/OCR/picker | Inyectar reloj y dependencias en los puntos de entrada para reproducir fechas y fallos sin red/cámara reales. |
| ARC-04 | P2 | Los tres proveedores crean `http.Client`; no hay cierre/propiedad explícita | Definir quién crea y cierra los clientes. Compartirlos durante una sesión; cerrar los del trabajo de fondo al terminar. |
| ARC-05 | P2 | `bcv_cache_service.dart:21-40,64-108`: se recorre y decodifica toda la caché en múltiples consultas | Medir antes de cambiar de almacenamiento; reutilizar una lectura por operación y definir retención. SharedPreferences sigue siendo suficiente para el volumen actual. |
| ARC-06 | P2 | `.clinerules:12` apunta a `docs/ai-context.md`, eliminado; varios ADR describen Rafnix/scrapers | Actualizar referencias y marcar ADR sustituidos por DEC-015, conservando su valor histórico. |

`TextEditingController` dentro del ViewModel es una decisión documentada en DEC-003. No es necesario moverlo para realizar este trabajo; el widget Android y los procesos de fondo deben consumir servicios de datos, no ese ViewModel.

### 3.4 Estructura objetivo incremental

Rutas propuestas, no archivos ya existentes:

```text
lib/
  theme/app_theme.dart
  models/
    tasa_bcv.dart                    # existente; compatibilidad de caché
    resultado_tasa.dart              # datos + metadatos de consulta
    cotizacion_usdt.dart             # valor, fuente y fecha propios
    documento_ocr.dart               # texto + geometría de la imagen
    seleccion_ocr.dart               # selección y candidatos monetarios
    widget_snapshot.dart             # contrato Dart ↔ Android
  services/
    tasa_repository.dart             # fuente compartida de reglas de tasas
    bcv_cache_service.dart
    ocr_service.dart                 # adaptación de ML Kit
    image_input_service.dart         # cámara/galería, recuperación y archivos
    home_widget_service.dart         # serialización y publicación nativa
    background_refresh_service.dart # tarea headless
  viewmodels/
    conversor_viewmodel.dart
    ocr_viewmodel.dart
  screens/
    conversor_screen.dart
    camera_capture_screen.dart
    ocr_selection_screen.dart
    settings_screen.dart
  widgets/
    rates_card.dart
    currency_selector.dart
    date_context_selector.dart
    conversion_card.dart
    rate_status_banner.dart
    ocr_image_overlay.dart
  utils/
    feriados_ve.dart                  # política temporal centralizada
    numeros_ocr.dart                  # parser compartido, endurecido
    ocr_coordinate_mapper.dart
```

Crear cada archivo cuando lo necesite su fase. El objetivo es separar responsabilidades concretas; no hace falta introducir otra biblioteca de estado ni una reorganización completa del repositorio.

## 4. Auditoría de lógica y datos

### LOG-01 — Conversión con tasa ausente y resultados anteriores visibles · P1

**Evidencia:** `conversor_viewmodel.dart:225-277,297-338`; `tasa_bcv.dart:61-71`; `bcv_cache_service.dart:110-135`.

- Si falla USDT, se libera `_cargandoUsdt`, pero `tasaActual` puede seguir en cero.
- `convertir()` divide sin comprobar `tasaActual > 0` ni `isFinite`.
- Una entrada inválida retorna sin borrar el resultado anterior.
- La deserialización convierte campos ausentes a cero y la caché no valida tasas positivas/finitas.

**Reproducción confirmada:** cargar USD válido → seleccionar USDT cuyo proveedor retorna `null` → invertir dirección → introducir `10`: resultado `Infinity`. Introducir `10` y después `,` mantiene el resultado de `10`. Una tasa cero se admite en caché exacta.

**Corrección propuesta:** disponibilidad por moneda; validar tasa, monto y resultado; ante entrada incompleta limpiar resultado; representar ausencia como ausencia, no como cotización cero. Diferenciar monto cero válido de tasa cero inválida.

**Aceptación:** nunca aparece `Infinity`, `NaN` ni un resultado perteneciente a otra entrada. USDT no disponible muestra estado y reintento propios; USD/EUR continúan utilizables.

### LOG-02 — Frescura incorrecta en días no hábiles · P1

**Evidencia:** `tasa_repository.dart:25-45,231-239`.

Si la fecha efectiva es anterior a hoy, `_esTasaVigente()` responde únicamente según si **hoy** es no hábil. No comprueba cuántos días hábiles faltan ni cuándo se validaron esos datos.

**Reproducción confirmada:** marcar hoy como feriado, guardar solo una tasa del 03/08/2026 y disponer de un proveedor con datos recientes: `obtenerTasa()` devuelve agosto sin llamar al proveedor.

**Corrección propuesta:** separar fecha aplicable de frescura de la consulta. Aceptar como vigente la última fecha efectiva esperada según calendario verificado; una tasa anterior sigue siendo respaldo offline, pero debe provocar intento de actualización y aviso de antigüedad.

**Aceptación:** viernes aplicable durante el domingo funciona; una tasa de semanas atrás no queda validada por ser domingo. Cubrir apertura antes/después de las 14:00 y cambio de día con reloj inyectado.

### LOG-03 — Fallbacks detenidos antes de encontrar la mejor tasa aplicable · P1

**Evidencia:** `tasa_repository.dart:71-85,95-126,143-204`.

- Una respuesta futura del primer proveedor puede devolver inmediatamente una caché vieja e impedir consultar los siguientes.
- La recuperación del histórico actual solo ocurre cuando no existe caché, aunque la existente sea insuficiente.
- Histórico y tasa anterior paran en el primer resultado elegible. Comparan ese resultado con caché, pero no con un fallback más próximo a la fecha solicitada.

**Reproducciones confirmadas:** proveedor principal futuro + caché de agosto + fallback del 25/09 → se devuelve agosto; histórico principal del 09/09 + fallback exacto del 11/09 → se devuelve 09/09 sin consultar el segundo.

**Corrección propuesta:** distinguir respuesta técnicamente válida de respuesta que satisface la fecha/frescura solicitada. Continuar fallbacks cuando el resultado es insuficiente; elegir la mayor fecha efectiva elegible. DolarAPI conserva prioridad entre candidatos equivalentes.

**Aceptación:** conservar próximos valores sin convertirlos en actuales; preferir fecha histórica más cercana disponible; respetar un presupuesto total de consulta para no recorrer fuentes indefinidamente.

### LOG-04 — Heurística de igualdad descarta fechas explícitas · P1

**Evidencia:** `tasa_repository.dart:131-139`.

Valores iguales no prueban que una nueva fecha sea incorrecta: una tasa puede mantenerse dos días. Actualmente, una tasa futura con los mismos USD/EUR se reemplaza por la caché y se pierde la próxima fecha.

**Reproducción confirmada:** cotización vigente de 100/110 y próxima de 100/110 con fecha explícita → `obtenerTasaSiguiente()` retorna `null`.

**Corrección propuesta:** registrar si la fecha es explícita o inferida. Respetar fechas explícitas del contrato validado. Limitar cualquier heurística a fechas inferidas y documentar su alcance.

### LOG-05 — USDT sin independencia de fecha, fuente y persistencia · P1

**Evidencia:** `chitty_bcv_service.dart:63-90`; `tasa_repository.dart:207-217`; `conversor_viewmodel.dart:66-67,101-113,192-202,225-277`.

- `obtenerUsdt()` retorna un `double`, perdiendo la fecha del promedio P2P.
- Se elige el último día disponible sin política de antigüedad.
- El valor se mezcla con el objeto BCV y hereda su origen y fecha.
- La carga bajo demanda no persiste USDT. Los proveedores actuales guardan `usdt: 0` en la caché oficial.
- Una vez cargado un valor positivo, `_necesitaUsdt` evita volver a consultarlo; actualizar las tasas oficiales conserva el valor antiguo.
- Si solo USDT está disponible, se construye un objeto con USD/EUR cero y estado general listo.
- El calendario se oculta para USDT, pero la fecha histórica seleccionada puede seguir en el estado interno.

**Corrección propuesta:** `CotizacionUsdt` independiente con valor, día del promedio, proveedor, momento de descarga y estado. Caché propia y TTL configurable. Mantener separados el contexto histórico BCV y el contexto actual P2P.

**Aceptación:** reiniciar offline conserva el último USDT con su antigüedad real; refrescar USDT hace una consulta cuando corresponde; su fuente no aparece como DolarAPI. El dato observado es un promedio diario, no una cotización en vivo por minuto.

### LOG-06 — Contratos temporales parcialmente inferidos y próxima tasa desaprovechada · P1

**Evidencia:** `bcv_api_service.dart:134-150,153-176`; `chitty_bcv_service.dart:29-53,120-130`; `tasa_repository.dart:219-229`.

- DolarAPI usa directamente año/mes/día del `DateTime` parseado. Un timestamp con offset se normaliza a UTC en Dart; cerca de medianoche eso puede cambiar el día venezolano. Los payloads observados a las 00:00 -04:00 no muestran ese problema, pero no cubren el caso límite.
- En Chitty, si falta o es inválido `updated_at`, se usa `DateTime.now()`: datos sin fecha pueden parecer recién publicados.
- La fecha inferida desde `updated_at` no equivale necesariamente a fecha valor.
- El objeto real `adelantada.aplica_desde` no se procesa.
- Los históricos DolarAPI contienen fechas futuras, pero solo se devuelve y guarda el candidato solicitado. La próxima tasa se descubre únicamente si llega a caché por otro camino.

**Corrección propuesta:** fecha civil efectiva separada de instantes UTC; adaptación temporal específica de cada proveedor y procedencia de fecha explícita/inferida. Incorporar próxima tasa validada al resultado de proveedores que la ofrecen, sin cambiar la cotización aplicada hoy.

**Aceptación:** UTC y UTC-4 alrededor de medianoche producen el mismo día venezolano correcto; un `YYYY-MM-DD` efectivo no sufre conversión de zona; una fecha faltante no se reemplaza por ahora. La tasa del lunes publicada el fin de semana queda disponible como próxima.

### LOG-07 — Calendario bancario insuficiente como autoridad de validación · P1

**Evidencia:** `feriados_ve.dart:1-17,48-71`; `feriados_service.dart:7-8,40-64`; `bcv_cache_service.dart:14-18`.

- El calendario general de festivos de Google se trata como calendario bancario y se acepta cada `DTSTART` sin clasificar el evento.
- El fallback contiene 24/10 y omite fechas como 24/07, 12/10 y 24/12; requiere contraste integral con el calendario bancario de cada año.
- Caso contrastado: la Asociación Bancaria de Venezuela muestra **14/09/2026** como feriado bancario trasladado por la Virgen de Coromoto. No figura en el fallback matemático actual.
- La caché descarta entradas basándose en esa lista. Un calendario equivocado puede hacer desaparecer una cotización previamente guardada.
- Los tests actuales incluyen 24/10 por copiar el listado de implementación; eso no valida su exactitud externa.

**Corrección propuesta:** calendario bancario anual versionado y documentado, centralizado en `feriados_ve.dart`; Google no debe invalidar cotizaciones explícitas por sí solo. Diferenciar fecha oficial publicada, calendario de referencia y heurísticas.

**Aceptación:** datos offline verificables para años soportados, feriados trasladados, 14/09/2026 y límites de año. Los tests deben basarse en fuentes del calendario, no en repetir constantes. La consulta a BCV/Sudeban falló durante esta auditoría; la referencia accesible fue Asobanca, que declara basarse en Sudeban.

### LOG-08 — No existe estado suficiente para offline y frescura honestos · P1

**Evidencia:** `tasa_bcv.dart:3-18`; `tasa_repository.dart:65-85`; `bcv_cache_service.dart:137-151`; `conversor_screen.dart:543-566`.

`origen` identifica al proveedor, no si el dato viene de red o disco. `ultima_consulta_api` se registra antes de consultar y también queda actualizado cuando fallan todas las fuentes. La UI no puede distinguir éxito reciente, respaldo offline y lectura normal de caché.

**Contrato recomendado:** envolver la cotización en un `ResultadoTasa` con:

| Campo conceptual | Significado |
|---|---|
| `tasa` | Valores y fecha efectiva validada |
| `siguiente` | Próxima cotización validada, si existe |
| `proveedor` | Fuente original del dato |
| `modoObtencion` | Red o caché |
| `fechaPublicacionUtc` | Instante del proveedor, si existe y está definido como tal |
| `ultimaValidacionExitosaUtc` | Última consulta exitosa que confirmó estos datos |
| `ultimoIntentoUtc` | Intento más reciente, incluso fallido |
| `estadoFrescura` | Vigente, antiguo o desconocido |
| `fechaInferida` | Si la fecha efectiva proviene de una heurística |
| `errorActualizacion` | Error tipado opcional; no sustituye una tasa utilizable |

Una lectura normal de caché no demuestra que el teléfono esté offline. Mostrar **“Guardada”**; si falló actualizar, **“No se pudo actualizar · usando tasa guardada”**. El estado de red del teléfono tampoco prueba que la API esté accesible.

### LOG-09 — Ciclo de vida y operaciones secundarias bloquean la carga · P1/P2

**Evidencia:** `conversor_viewmodel.dart:72-172,174-223,225-285,344-348`.

- **Confirmado:** completar una consulta después de `dispose()` puede ejecutar `notifyListeners()` sobre el ViewModel destruido. Las generaciones no se invalidan al destruirlo.
- La notificación final de la tasa espera el histórico para la variación; un dato secundario retrasa la presentación de la tasa principal.
- Al cambiar de moneda se notifica antes de recalcular. Durante la espera puede coexistir la etiqueta nueva con el resultado anterior.
- Las generaciones de moneda y carga protegen parte de las carreras, pero no forman una sesión conjunta de consulta, moneda y fecha.

**Corrección propuesta:** invalidar operaciones al destruirse; aplicar resultados solo a su contexto; mostrar la cotización en cuanto esté lista; calcular variación aparte y limpiar resultados mientras cambian sus dependencias.

### LOG-10 — Coste de históricos, caché y tratamiento de errores · P2

**Evidencia:** `bcv_api_service.dart:57-64`; `bcv_today_service.dart:42-63`; `bcv_cache_service.dart:25-36,110-125`; `tasa_repository.dart:65-81`.

- DolarAPI descarga las dos listas completas por consulta histórica no resuelta en caché.
- BCV Today permite **32 solicitudes secuenciales** por búsqueda (`0..31`). Un timeout interrumpe ese proveedor, pero muchos 404 lentos pueden prolongar la consulta considerablemente.
- `prefs.getString()` queda fuera del `try`: una clave con tipo distinto puede romper la lectura completa.
- Una escritura fallida puede tratarse como fallo de proveedor; incluso registrar el intento antes del bucle puede impedir consultar red si falla almacenamiento.

**Propuesta:** presupuesto total y cancelación/invalidez de resultados tardíos; memoización breve de históricos compartida por la sesión; degradación por entrada corrupta; separar fallos de red y persistencia. Una tasa válida de red puede mostrarse aunque no haya podido guardarse.

### Comportamientos adicionales que deben quedar definidos

- `toggleDireccion()` usa el resultado redondeado a dos decimales como nueva entrada (`conversor_viewmodel.dart:302-311`, DEC-003). Conservar inicialmente ese contrato; cualquier mejora de precisión debe documentarse y probarse aparte.
- El calendario empieza en 2016 (`conversor_screen.dart:233`), pero el histórico DolarAPI observado empieza en 2023. Mostrar cobertura real y “Sin datos”, sin afirmar cobertura desde 2016 por tener esa fecha habilitada.
- “Volver a hoy” solo aparece cuando la selección es anterior a hoy (`conversor_screen.dart:192-194`). Debe permitir salir también de una selección futura y del modo histórico seleccionado explícitamente para hoy.

## 5. Auditoría UI/UX y adaptación de Stitch

### 5.1 Referencias recomendadas

| Carpeta | Uso recomendado |
|---|---|
| `stitch/cuantoes_bcv_principal_modo_claro_real/` | Referencia visual principal para tema claro |
| `stitch/cuantoes_bcv_principal_modo_oscuro/` | Referencia visual principal para tema oscuro |
| `stitch/cuantoes_bcv_principal_modo_claro/` | Variante de comparación: su HTML tiene `class="dark"` y su captura es oscura |
| `stitch/cuantoes_bcv_ajustes_ocr_y_calendario/` | Ideas para ajustes, elección de imagen y calendario; el OCR necesita una pantalla de selección adicional |
| `stitch/cuantoes_bcv_estados_offline_error_y_usdt/` | Jerarquía de avisos y distinción P2P; convertir simulaciones en estados reales |
| `stitch/sovereign_exchange/DESIGN.md` | Base de tokens; resolver diferencias entre el front matter, la prosa y los HTML |

### 5.2 Qué adoptar

- Tarjeta USD/EUR con fecha efectiva, fuente y refresco visibles.
- Selector segmentado USD/EUR/USDT con etiqueta P2P.
- Conversor con entrada y resultado claramente diferenciados, intercambio central y copia con feedback.
- Acción OCR visible: **“Escanear texto”** o **“Escanear precio”**, con la selección de texto completa dentro del flujo.
- Accesos rápidos 1/10/50/100 relativos a la moneda de entrada, incluida VES al invertir.
- Superficies claras/oscuras coherentes y números tabulares.
- Aviso discreto de tasa guardada y de fecha aplicada en histórico.

### 5.3 Ajustes necesarios a las maquetas

| Elemento de Stitch | Adaptación para Cuantoes |
|---|---|
| “BCV Directo” | Eliminar del texto de fuentes: el scraper ya fue retirado |
| “Persistencia offline cifrada activa”, “SQLite/IDB” | Sustituir por “Última tasa guardada”; hoy se usa SharedPreferences sin una capa de cifrado implementada por la app |
| “Confianza 98/95/84%” | Son cifras simuladas. ML Kit Android ofrece confianza opcional por línea/elemento, no certeza de que un precio sea el elegido o esté vigente |
| “Precio combo x2 tachado” | El OCR actual no clasifica tachados, combos ni precio unitario; no asumir esa semántica |
| “Promedio Binance / El Dorado / Kontigo” | Mostrar la procedencia documentada de Chitty; no inventar exchanges contribuyentes |
| Variación USDT | Omitir mientras no exista una definición y cálculo propios |
| “Regulación BCV art. 138”, aplicación “legal” de cierres | Sustituir por explicación de la fecha realmente aplicada; no trasladar afirmaciones de la demo |
| “Simular casos de red y mercado” | Es control de maqueta; los estados de producción deben venir de datos reales |
| Tasas, fechas, versión `v2.4`, cantidad/tamaño de caché | Mostrar datos reales; versión actual declarada: `1.0.0+1` |
| Selector de proveedor preferido | Mantener DolarAPI → BCV Today → Chitty, conforme a la decisión existente |
| Tres pestañas “Tasas / Calculadora / Historial” | Recomiendo inicio integrado, calendario modal y ajustes. La maqueta ya junta tasas y cálculo; no hay tres destinos independientes implementados |
| “Sin comisiones” | Preferir “Conversión de referencia”; la app calcula, no ejecuta operaciones |
| Puntos de “cotización publicada” en todos los días del calendario | Mostrar solo si existe evidencia de esos datos; habilitar una fecha no prueba que tenga registro exacto |

### 5.4 UX-01 — Adaptabilidad y accesibilidad · P1

**Evidencia:** `conversor_screen.dart:48-70,199-213,523-539`. Layout principal en `Column` con `Spacer`, sin scroll; filas de fechas y tasas rígidas. Las pruebas UI existentes usan 1080 × 1920 a DPR 1, un espacio lógico mucho mayor que un teléfono habitual.

**Reproducción confirmada:** viewport lógico 360 × 640 y teclado de 280 px produce desbordamientos verticales y horizontales.

**Diseño propuesto:**

1. AppBar compacta: Cuantoes, estado resumido y ajustes.
2. Tarjeta de tasas, compactable al abrir teclado.
3. Moneda y contexto de fecha.
4. Entrada, intercambio y resultado en contenido desplazable.
5. Atajos y detalle de fuente/antigüedad.

Usar `CustomScrollView`/`ListView`, `SafeArea`, restricciones de ancho y filas flexibles. El conversor debe seguir visible y operable con teclado. Evitar `Spacer` dentro de scroll sin restricciones y no resolver números largos reduciendo ilimitadamente su fuente.

**Criterios:** 320/360/390 dp de ancho, orientación horizontal, texto al 200%, resultado grande, TalkBack, orden de foco y teclado. Áreas táctiles de al menos 48 dp; contraste AA; cambios de estado con texto/icono además de color. El botón de intercambio necesita etiqueta accesible.

### 5.5 Tokens y estados

- Claro: base `#F8FAFC`, tarjetas `#FFFFFF`, texto `#0F172A`, acción `#2563EB`.
- Oscuro: elegir coherentemente la familia de `principal_modo_oscuro`/front matter (`#0B1326`, `#171F33`, `#DAE2FD`); no mezclarla por accidente con todas las variantes slate del documento.
- Radios propuestos: tarjetas 16 dp, campos 12 dp; espaciado 4/8/12/16/24/32.
- Números tabulares; formato venezolano para todas las monedas. Importes con dos decimales, detalle de cálculo y tasa con precisión suficiente, sin redondear la tasa antes de operar.
- Si se adoptan Inter/Plus Jakarta Sans, incluir archivos y licencias como assets para funcionamiento offline. Una fuente de sistema también permite empezar sin dependencias extra.
- Inicial: skeleton; refrescando: conservar datos visibles; caché: distinguir lectura normal de actualización fallida; error sin datos: reintento; USDT: estados propios; histórico: fecha solicitada y aplicada; próximo: etiqueta separada.
- Stitch muestra variación simultánea USD/EUR; hoy existe un solo `variacion` para la moneda seleccionada. Calcular ambas a partir del mismo par anterior o mostrar únicamente la disponible; no duplicar un porcentaje.

## 6. Auditoría OCR y experiencia de selección sobre imagen

### 6.1 Qué existe y qué falta

Actualmente: tomar foto con `camera`, elegir imagen con `image_picker`, ejecutar ML Kit Latin y abrir un diálogo con texto seleccionable y hasta 12 chips numéricos.

La selección existente ocurre **en un TextField con el texto reconocido**, no sobre la foto. La experiencia solicitada requiere conservar imagen y geometría, además de gestionar gestos de selección.

El paquete instalado `google_mlkit_text_recognition 0.17.1` ya expone:

- `RecognizedText.blocks`.
- Bloques, líneas y elementos con `boundingBox` y `cornerPoints`.
- Símbolos/caracteres en Android, cuando estén disponibles.
- Confianza y ángulo opcionales en Android.

El servicio actual devuelve únicamente `resultado.text` (`ocr_service.dart:4-9`), descartando todo lo demás. **El motor existente sirve; el trabajo central está en conservar sus resultados y construir la interacción.** ML Kit reconoce texto; no entrega una interfaz Google Lens lista para incrustar.

### 6.2 Hallazgos OCR

| ID | Prioridad | Evidencia y efecto | Acción propuesta |
|---|---|---|---|
| OCR-01 | P1 | `ocr_service.dart:4-9`: pérdida de geometría e imagen | Retornar documento estructurado y conservar ruta/dimensiones de la imagen procesada |
| OCR-02 | P1 | `numeros_ocr.dart:28-60`; `_usarSeleccion` en `conversor_screen.dart:646-656`: elimina caracteres y, sin selección, parsea todo el texto | Exigir un solo candidato monetario válido; varios números no se concatenan |
| OCR-03 | P1 | `numeros_ocr.dart:11-20`: deduplica por valor; chips limitados en `conversor_screen.dart:691` | Mantener identidad y ubicación de cada aparición; dos precios iguales en lugares distintos deben poder seleccionarse |
| OCR-04 | P1 | `conversor_screen.dart:372-373`: aplica solo un String a la entrada activa | Confirmar monto y moneda de origen para no tratar un precio en Bs. como USD |
| OCR-05 | P1 | `conversor_screen.dart:269,727-729`: teclado admite 2 decimales; OCR inserta hasta 4 directamente | Unificar entrada manual, OCR, pegado y atajos. Insertar monto normalizado sin volver a desplazarlo como centavos |
| OCR-06 | P1 | `camera_capture_screen.dart:22-49,52-66`: varios `setState` tras `await` sin comprobar montaje; no observa lifecycle | Gestión de pausa/reanudación, cierre de recursos y respuestas tardías; error recuperable de permisos/cámara |
| OCR-07 | P2 | `conversor_screen.dart:324-355`: sin `retrieveLostData`; fallo OCR se transforma en texto vacío; spinner se cierra con un `pop` genérico | Recuperar selección tras muerte de Activity y distinguir cancelación, error y texto vacío; carga gestionada en la propia ruta OCR |

**Casos confirmados del parser actual:**

| Entrada | Resultado actual | Problema |
|---|---:|---|
| `10 20` | `1020` | Une dos cantidades |
| `12,34,56` | `123456` | Acepta agrupación inválida |
| `-10` | `10` | Elimina el signo y cambia el valor |
| `0,125` | `125` | La regla de tres cifras interpreta miles en un caso decimal plausible |
| `1,23456` | `123456` | Más de cuatro decimales se convierten en miles |

### 6.3 Flujo objetivo

```text
Escanear texto
  → Tomar foto / Elegir imagen
  → Preparar imagen y reconocer
  → Foto con texto resaltado y zoom
  → Tocar palabra/monto o mantener y arrastrar selección
  → Texto seleccionado
       ├─ Copiar texto
       └─ Usar monto → revisar/editar monto y moneda → conversor
```

**Interacciones requeridas:**

- Selección de texto arbitrario, no exclusivamente números.
- Tap para palabra/monto; pulsación larga y manejadores para ampliar a palabras y líneas.
- Zoom y desplazamiento de la foto, con resaltado siempre alineado.
- Seleccionar todo, limpiar selección, repetir foto y volver a galería.
- Panel inferior con texto seleccionado y acciones “Copiar” / “Usar monto”.
- Si hay varios montos, elegir uno; si no hay un monto válido, mantener disponible copiar texto.
- Editor de monto antes de transferirlo, útil ante errores OCR o separadores ambiguos.
- Alternativa accesible con lista de líneas y texto seleccionable, sincronizada con la selección visual.

El objetivo inicial es fotografía estática + selección. Esto cumple la interacción pedida y evita añadir procesamiento continuo de vídeo al mismo tiempo.

### 6.4 Contratos propuestos

**`DocumentoOcr`:** identificador de sesión, ruta de imagen normalizada, ancho/alto en píxeles, texto completo y regiones inmutables.

**`RegionOcr`:** ID estable, texto, IDs/índices de bloque-línea-elemento, orden de lectura, rectángulo, polígono y confianza opcional. Conservar símbolos si se necesita selección parcial dentro de un elemento y el motor los aporta.

**`SeleccionOcr`:** IDs seleccionados, texto reconstruido con espacios/saltos de línea y candidatos monetarios asociados a sus posiciones.

**`MontoDetectado`:** texto original, representación decimal normalizada, moneda sugerida opcional y ambigüedades de parseo. La deduplicación por valor no debe eliminar regiones.

La UI consume estos modelos propios. El adaptador de ML Kit transforma el resultado nativo; el parser monetario sigue siendo una utilidad independiente y comprobable.

### 6.5 Coordenadas: la parte crítica

1. Normalizar orientación EXIF una vez y obtener las dimensiones reales de **la misma imagen** enviada a OCR y mostrada al usuario.
2. Mantener regiones en coordenadas de esa imagen, no en posiciones de pantalla.
3. Para `BoxFit.contain`, calcular escala `s = min(anchoVista/anchoImagen, altoVista/altoImagen)` y desplazamiento de centrado `o`.
4. Colocar imagen y overlay en el mismo hijo de `InteractiveViewer`; ambos reciben la misma transformación de zoom/desplazamiento.
5. Relación conceptual: `pVista = MZoomPan × (o + s × pImagen)`.
6. Para un toque: convertir primero a coordenadas locales del viewport; aplicar `TransformationController.toScene`; después quitar `o` y dividir por `s`.
7. Usar `cornerPoints` para texto inclinado; el rectángulo puede ayudar a localizar candidatos, pero no sustituye siempre al polígono.
8. Añadir tolerancia táctil expresada en dp y transformada a coordenadas de imagen. Resolver colisiones entre regiones cercanas por contención/distancia y orden de lectura.
9. No ordenar toda una página solamente por Y/X: respetar bloques y líneas para evitar mezclar columnas.

Evitar transformar dos veces el overlay o usar dimensiones del preview de cámara para una foto con otra orientación. Un `SelectableText` colocado encima de la foto no alinea automáticamente su tipografía con las regiones OCR.

### 6.6 Parser y transferencia al conversor

- Validar gramática y agrupación de separadores antes de eliminar caracteres.
- Conservar soporte de `1.234,56`, `1,234.56`, `10.50` y `848,5458`.
- Tratar separadores ambiguos como dato a revisar; no convertir silenciosamente decimales en miles.
- Reconocer sugerencias `Bs.`, `VES`, `USD`, `US$`, `EUR`, `€` y `USDT` en contexto; `$`/`Ref` requieren interpretación visible.
- No corregir automáticamente `O→0`, `S→5` o signos perdidos sin mostrar el texto y permitir edición.
- El monto elegido debe ser finito y respetar el rango/precisión acordados. No eliminar negativos para convertirlos en positivos.
- Un precio VES debe establecer entrada VES; una divisa, su moneda y dirección correspondiente. Aplicar el cambio mediante una acción coherente del ViewModel, sin estados intermedios con moneda equivocada.
- La coma automática afecta tecleo de centavos. Un valor ya interpretado por OCR debe insertarse tal cual y seguir siendo editable.

### 6.7 Cámara, calidad y recursos

- `camera` exige que la app gestione lifecycle: liberar al quedar inactiva y reabrir al reanudar cuando corresponda.
- Comprobar `mounted`/sesión antes de toda actualización tardía y liberar el controlador local si falla inicializar.
- Estados de permisos denegados, cámara no disponible, captura fallida, imagen ilegible y texto vacío deben permitir recuperación.
- Recuperar `ImagePicker.retrieveLostData()` al arrancar cuando haya una selección pendiente.
- Tratar cada captura como una sesión; impedir dos procesamientos simultáneos y descartar resultados de sesiones canceladas.
- Normalización y reducción de imagen deben preservar caracteres legibles; definir límites de memoria con fotos reales, no usando una miniatura de la maqueta como entrada.
- Eliminar únicamente copias temporales propiedad de la sesión después de terminar su uso; conservar el original elegido por el usuario.
- El modelo Latin está empaquetado en la dependencia Android observada (`com.google.mlkit:text-recognition:16.0.1`). Verificar OCR sin red desde primera ejecución del APK release.
- El manifiesto fuente solo declara Internet, pero el manifiesto fusionado disponible **sí contiene CAMERA**. No diagnosticar un permiso faltante mirando únicamente el archivo fuente. También aparecen permisos heredados de audio/almacenamiento; revisar su necesidad al cerrar la integración de foto/galería.

## 7. Widgets para el homescreen de Android

### 7.1 Estado auditado

- `MainActivity.kt` es una `FlutterActivity` vacía.
- No hay `AppWidgetProvider`, XML de widget, layout nativo, configuración por instancia ni sincronización de datos.
- `pubspec.yaml` no incluye `home_widget` ni `workmanager`.
- Los `testWidgets` de Flutter existentes prueban pantallas de la app; no prueban widgets del launcher.

### 7.2 Implementación recomendada

**Flutter + `home_widget` para compartir snapshots; Kotlin + XML/RemoteViews para renderizar; `workmanager` para actualización periódica.**

RemoteViews es suficiente para tarjetas de tasas y reduce cambios de compilación en este proyecto. La documentación actual de home_widget recomienda Glance para desarrollos nuevos, pero mantiene soporte XML; esta recomendación prioriza el alcance sencillo y la configuración Android existente. Elegir una sola vía nativa para esta entrega.

Un widget Android no es un árbol Flutter ejecutándose en el launcher. Compartir reglas de datos y diseño visual; implementar layout, acciones y accesibilidad con los componentes nativos admitidos.

### 7.3 Entregas funcionales

| Entrega | Contenido |
|---|---|
| W1 — 4×2 | USD/EUR, fecha efectiva, fuente, última sincronización, indicador de dato guardado; tocar abre la app |
| W2 — actualización de fondo | Refresco periódico y acción de actualizar, preservando la última tasa cuando falla red |
| W3 — 2×2 configurable | Moneda seleccionable por instancia; USDT únicamente con metadatos P2P y caché propios; adaptación de tamaño y tema |

Los tamaños en celdas son orientativos: cada launcher tiene su cuadrícula. Definir mínimos en dp y responder a redimensionamiento.

Ejemplo conceptual W1:

```text
Cuantoes                 Actualizar
USD          Bs. 855,6625
EUR          Bs. 972,6487
Fecha valor: 25/09/2026
DolarAPI · sincronizado hace 12 min
```

No usar “actualizado hace…” para representar la fecha efectiva. Separar cuándo se descargó/validó de para cuándo aplica la cotización.

### 7.4 Contrato de snapshot

Crear un payload versionado, pequeño e inmutable, por ejemplo bajo la clave **`cuantoes_widget_snapshot_v1`**:

- `schemaVersion` y revisión de datos.
- USD/EUR actuales válidos y fecha efectiva civil.
- Próxima cotización validada, cuando exista, marcada separadamente.
- Proveedor y procedencia explícita/inferida de la fecha.
- Instante real de última validación exitosa, último intento y estado de actualización.
- USDT opcional, con fecha y proveedor independientes.
- Preferencia de tema cuando proceda; configuración de moneda/tamaño por `appWidgetId` en un espacio separado.

Guardar el JSON como **un String** con `HomeWidget.saveWidgetData<String>` y luego solicitar `HomeWidget.updateWidget`. Eso evita un snapshot parcialmente compuesto por múltiples claves, pero **no resuelve por sí solo escrituras concurrentes entre engines**.

El almacenamiento de home_widget no es automáticamente el mismo que usa `shared_preferences`. `HomeWidgetService` es el puente explícito; Kotlin lee los datos de home_widget y se limita a validación defensiva, formato y render.

**Regla esencial:** visitar una fecha histórica dentro de la app no puede publicar esa fecha como tasa actual del widget. Construir el snapshot desde la consulta actual del repositorio, no desde cualquier cambio de `vm.tasa` ni desde cada escritura de caché.

### 7.5 Archivos Android propuestos

```text
android/app/src/main/
  kotlin/ve/cuantoes/cuantoes/widget/
    TasasWidgetProvider.kt
    TasasWidgetConfigActivity.kt       # al implementar W3
  res/layout/
    tasas_widget.xml
    tasas_widget_compact.xml           # W3
  res/xml/
    tasas_widget_info.xml
  res/drawable/
    widget_background.xml
    widget_preview.xml
  res/values/ y res/values-night/
    recursos de colores, dimensiones y textos del widget
  AndroidManifest.xml
```

- Registrar receiver, acción `APPWIDGET_UPDATE` y meta-data de `appwidget-provider`; declarar exportación explícita conforme a la integración elegida.
- Configurar layout inicial, mínimos, modo de resize, preview y celdas objetivo cuando la API lo soporte.
- Usar `updatePeriodMillis="0"` al delegar periodicidad a WorkManager.
- `onUpdate` lee el snapshot y actualiza todas las instancias; `onAppWidgetOptionsChanged` adapta el tamaño.
- Estado sin datos: “Abre Cuantoes para cargar las tasas”, sin cotizaciones ficticias ni ceros.
- Acciones con PendingIntent explícito e identidad por instancia/acción; abrir conversor y manejar arranque frío y app ya abierta.
- La acción de actualizar en W1 puede abrir la app con esa intención; en W2 pasa a encolar trabajo de fondo. El texto de la acción debe reflejar la conducta de su entrega.

### 7.6 Actualización y coherencia

1. Publicar snapshot al obtener una tasa actual válida, al recuperar caché inicial y al cambiar ajustes relevantes.
2. La lectura inicial debe poder mostrar datos guardados inmediatamente.
3. Registrar un trabajo periódico único para widgets activos; propuesta inicial: **60 minutos**, ajustable tras medir consumo.
4. En el callback headless, inicializar binding/plugins y dependencias según la versión de Workmanager; cargar calendario y almacenamiento. No acceder a `BuildContext` ni construir el ViewModel de pantalla.
5. Ejecutar primero la etapa local: resolver fechas actuales y próximas desde caché y publicar. Esta etapa debe poder correr sin conexión.
6. Después intentar refrescar proveedores con presupuesto total acotado, reutilizando el repositorio y sus reglas. Si falla, conservar números y última validación exitosa, y actualizar el estado del intento.
7. Añadir backoff a reintentos de red y coalescer pulsaciones repetidas de actualizar. Cancelar trabajo periódico cuando ya no haya widgets activos y restablecerlo cuando corresponda.
8. Invalidar/recargar lecturas de SharedPreferences al cruzar engines. El caché del singleton legacy y `_refreshEnCurso` solo protegen su propia instancia/isolate.
9. Preservar claves actuales al evolucionar almacenamiento. Migrar a `SharedPreferencesAsync` sin configurar/migrar el backend legacy puede hacer que las tasas previas dejen de encontrarse.
10. Establecer un único punto de commit del snapshot con desempate por fecha efectiva, publicación conocida y prioridad de fuente. Serializar la publicación entre foreground/background o implementar comparación y escritura atómica en el puente nativo; un mutex Dart no coordina dos engines.

**Límites de plataforma que forman parte del diseño:** WorkManager periódico tiene mínimo de 15 minutos y ejecución aproximada; `updatePeriodMillis` nativo no ofrece periodos inferiores a 30 minutos. No prometer actualización exacta a las 14:00. Un receiver no debe hacer consultas largas. Doze, restricciones del fabricante y force-stop pueden posponer trabajo; mostrar siempre la fecha/antigüedad para que el widget siga siendo interpretable.

## 8. Paso a paso de implementación para Luna

Cada paso indica entregable y criterio de salida. Las dependencias de datos deben estar resueltas antes de dibujar estados de red o publicar tasas en el launcher.

### Paso 0 — Preparar baseline y casos reproducibles

**Rutas:** `test/`, `docs/`, puntos de construcción en `main.dart` y servicios.

- [ ] Leer este documento, `doc.md`, `funciones.md` y los ADR vigentes.
- [ ] Registrar baseline de analyze/tests y versiones del entorno.
- [ ] Introducir reloj inyectable para escenarios temporales; fijar fecha/zona en pruebas.
- [ ] Incorporar fixtures de proveedores representativos, incluyendo próxima tasa y payloads inválidos.
- [ ] Convertir los casos confirmados de esta auditoría en pruebas de comportamiento esperado, inicialmente fallidas y ligadas a cada corrección.

**Salida:** los casos fallan por el problema esperado y son independientes del día real y la red.

### Paso 1 — Asegurar cálculo, validación y ciclo de vida

**Rutas:** `models/tasa_bcv.dart`, `viewmodels/conversor_viewmodel.dart`, `services/bcv_cache_service.dart`.

- [ ] Resolver LOG-01 y la parte de lifecycle de LOG-09.
- [ ] Validar importes/tasas finitos y disponibilidad por moneda.
- [ ] Limpiar resultado ante entrada incompleta o cambio de contexto.
- [ ] Invalidar respuestas al destruir ViewModel; probar carga/moneda/fecha concurrentes.
- [ ] Aislar entradas corruptas de caché y fallos de escritura.

**Salida:** no hay división por cero, resultados anteriores inconsistentes ni notificaciones tras dispose; USD/EUR utilizables aunque USDT falle.

### Paso 2 — Corregir fechas, frescura y selección de proveedores

**Rutas:** `tasa_repository.dart`, proveedores, `feriados_ve.dart`, `feriados_service.dart`, nuevo `resultado_tasa.dart`.

- [ ] Resolver LOG-02/03/04/06/07/08.
- [ ] Definir metadatos de resultado y serialización compatible con entradas legacy.
- [ ] Separar fecha civil efectiva, fecha de publicación y validación exitosa local.
- [ ] Verificar calendario bancario anual y definir comportamiento cuando falte cobertura.
- [ ] Continuar fallbacks cuando el resultado no satisfaga la fecha/frescura.
- [ ] Conservar próximas tasas explícitas incluso con valores iguales; capturar `adelantada` y pares históricos futuros verificados.
- [ ] Evitar que caché vieja o fallo de almacenamiento se interpreten como consulta satisfactoria.
- [ ] Acotar consultas históricas y compartir descargas repetidas de una misma sesión.

**Salida:** suite de viernes/domingo/feriado/medianoche/próxima fecha aprobada; mejor fecha aplicable y fuente real visibles mediante el contrato.

### Paso 3 — Separar USDT y completar estados de presentación

**Rutas:** nuevo `cotizacion_usdt.dart`, repositorio, persistencia y ViewModel.

- [ ] Resolver LOG-05 con caché, timestamp y fuente propios.
- [ ] Definir TTL y comportamiento de refresco explícito de USDT.
- [ ] Mantener histórico BCV separado de la referencia actual P2P.
- [ ] Entregar estado parcial: BCV listo y USDT cargando/error no bloquean toda la pantalla.
- [ ] Presentar tasa principal antes de esperar variaciones; si se muestran USD/EUR simultáneamente, calcular ambas con el mismo par anterior.

**Salida:** USDT persiste tras reinicio, funciona como respaldo offline identificado y se actualiza bajo demanda; no hereda origen/fecha BCV.

### Paso 4 — Extraer componentes y definir tema

**Rutas:** `screens/conversor_screen.dart`, `theme/`, `widgets/`, ajustes.

- [ ] Extraer tarjeta de tasas, selector de moneda, contexto de fecha, conversor, estados y ajustes.
- [ ] Permitir inyección de repositorio/estado para pruebas de pantallas.
- [ ] Aplicar una tabla de tokens clara/oscura basada en las dos referencias recomendadas.
- [ ] Mantener preferencias existentes; si se agrega tema “Sistema”, migrar los bool previos conservando la elección del usuario.
- [ ] Sustituir excepciones técnicas visibles por mensajes breves y acciones de recuperación.

**Salida:** componentes reciben datos/acciones definidos; cambios visuales no ejecutan consultas por reconstruirse un widget.

### Paso 5 — Implementar la UI/UX de Stitch adaptada

**Rutas:** componentes/pantallas anteriores y pruebas UI.

- [ ] Implementar inicio integrado con fuente, fecha efectiva, tasas y cálculo.
- [ ] Dar scroll y restricciones flexibles al contenido; garantizar teclado y texto grande.
- [ ] Conectar todos los estados a `ResultadoTasa` y `CotizacionUsdt`.
- [ ] Agregar feedback de copiar, limpiar y atajos coherentes con la dirección.
- [ ] Mostrar fecha solicitada/aplicada y acción de volver a tasa actual desde cualquier selección.
- [ ] Aplicar la tabla de correcciones de Stitch; usar datos reales y etiquetas de P2P.

**Salida:** revisar claro/oscuro, USD/EUR/USDT, histórico, próxima tasa, caché, error y teclado en 320–390 dp; pruebas de overflow y accesibilidad aprobadas.

### Paso 6 — Preparar OCR estructurado y captura robusta

**Rutas:** `ocr_service.dart`, `camera_capture_screen.dart`, `image_input_service.dart`, `documento_ocr.dart`, `ocr_viewmodel.dart`.

- [ ] Reemplazar la salida de texto plano por documento con regiones e IDs.
- [ ] Normalizar orientación y compartir imagen/dimensiones exactas entre detector y visor.
- [ ] Gestionar permisos, lifecycle, cancelación, errores y recuperación de galería.
- [ ] Mantener reconocedor y recursos ligados a la sesión; cerrar incluso ante fallos.
- [ ] Preparar fixtures de recibos/etiquetas y documentos con bloques/líneas/polígonos conocidos.

**Salida:** cada región puede relacionarse con su texto y posición en una foto; errores no se presentan como “sin texto” y se puede repetir el flujo.

### Paso 7 — Construir selección visual de texto

**Rutas:** `ocr_selection_screen.dart`, `ocr_image_overlay.dart`, `ocr_coordinate_mapper.dart`, `seleccion_ocr.dart`.

- [ ] Implementar foto + overlay en una misma escena transformable.
- [ ] Implementar hit testing, selección por toque, ampliación por pulsación/arrastre y manejadores.
- [ ] Coordinar gestos de zoom/pan con selección; una selección activa no debe impedir ampliar la imagen.
- [ ] Reconstruir texto según bloques/líneas, preservar espacios y permitir copiar texto arbitrario.
- [ ] Ofrecer lista accesible y selección textual alternativa.
- [ ] Mantener selecciones al cambiar tamaño/rotar cuando sea posible; si se reprocesa imagen, invalidarlas explícitamente.

**Salida:** el texto resaltado permanece bajo el dedo con zoom, márgenes, orientación y desplazamiento; dos números iguales son seleccionables por separado.

### Paso 8 — Endurecer interpretación monetaria y conectar OCR

**Rutas:** `numeros_ocr.dart`, selección OCR, ViewModel de conversión y formateadores.

- [ ] Resolver OCR-02/03/04/05 con parser contextual y gramática validada.
- [ ] Mostrar elección entre candidatos o edición para separadores ambiguos.
- [ ] Conservar formato venezolano y hasta cuatro decimales de entrada interpretada; definir comportamiento uniforme de edición manual.
- [ ] Aplicar monto/moneda/dirección mediante una sola acción coherente.
- [ ] Confirmar que coma automática no vuelva a dividir el monto reconocido entre cien.

**Salida:** foto de `Bs. 185,00 / Ref $5.00` permite escoger cualquiera y convertir en la dirección correcta; seleccionar ambos no produce un número fusionado.

### Paso 9 — Entregar widget 4×2 actualizado desde la app

**Rutas:** `pubspec.yaml`, `home_widget_service.dart`, `widget_snapshot.dart`, recursos Kotlin/XML y manifiesto.

- [ ] Elegir versión compatible de home_widget y verificar integración con AGP/Kotlin actuales.
- [ ] Implementar snapshot versionado y puente, separado del histórico visible.
- [ ] Implementar layout nativo, preview, estados vacío/caché/error y apertura de la app.
- [ ] Publicar desde carga/refresco actual y recuperación de caché.
- [ ] Actualizar todas las instancias y adaptar tamaño; probar tema claro/oscuro.

**Salida:** el widget aparece en el selector del launcher, muestra USD/EUR correctos y sobrevive al cierre normal del proceso con sus datos guardados.

### Paso 10 — Actualización de fondo y widget compacto

**Rutas:** `background_refresh_service.dart`, inicialización, puente nativo y configuración por instancia.

- [ ] Agregar Workmanager y entrypoint conservado en release con `@pragma('vm:entry-point')`.
- [ ] Implementar trabajo único, etapa local offline, refresco acotado, backoff y cancelación al quitar widgets.
- [ ] Resolver coherencia de preferencias y publicación entre foreground/background.
- [ ] Añadir actualización manual mediante trabajo encolado, sin HTTP largo en el receiver.
- [ ] Implementar W3: 2×2, elección de moneda por instancia y USDT con etiqueta P2P y su antigüedad.
- [ ] Manejar creación, resize, eliminación, reinicio/restauración y arranque desde acciones de widget.

**Salida:** verificación en launcher real con app cerrada, offline, proceso eliminado, reinicio y Doze; retrasos del sistema no producen etiquetas falsas de frescura.

### Paso 11 — Validación de integración y entrega ARM64

**Rutas:** `test/`, pruebas de integración Android, `Makefile`, documentación y configuración de build.

- [ ] Ejecutar análisis y pruebas de comportamiento; añadir pruebas de integración para OCR nativo y launcher.
- [ ] Probar el flujo completo en dispositivo ARM64: foto → selección → conversión → refresco → widget.
- [ ] Verificar arranque offline y persistencia después de cerrar/reabrir.
- [ ] Actualizar Makefile para que la entrega requerida genere release ARM64 explícitamente.
- [ ] Compilar `flutter build apk --release --target-platform android-arm64`.
- [ ] Inspeccionar el APK resultante: ABI nativas exactamente `arm64-v8a` y manifest no debuggable. No inferirlo solo por el nombre `app-release.apk`.
- [ ] Revisar firma antes de distribución pública: actualmente release usa `signingConfigs.getByName("debug")` (`android/app/build.gradle.kts:43-46`).
- [ ] Actualizar `doc.md`, `funciones.md`, ADR aplicables, README y `.clinerules` con las decisiones realmente implementadas.

**Salida:** APK release ARM64 verificado, matriz de pruebas documentada y documentación consistente con la implementación.

## 9. Matriz mínima de aceptación

| Área | Caso | Resultado esperado |
|---|---|---|
| Conversión | Tasa cero, negativa o no finita | No calcula; estado de dato inválido |
| Conversión | `10` → `,` / entrada vacía | Desaparece resultado anterior |
| Conversión | Cambio rápido USD/EUR/USDT y dirección | Etiqueta, tasa y resultado pertenecen al mismo contexto |
| Caché | Domingo con último viernes / con tasa de hace semanas | Viernes aplicable; antigua provoca refresco y aviso |
| Proveedores | Principal futuro, caché vieja, fallback vigente | Se conserva futuro y se usa vigente del fallback |
| Histórico | Principal incompleto, fallback/caché más cercano | Mayor fecha efectiva elegible |
| Fechas | Próxima fecha con valores iguales | Se conserva como próxima |
| Fechas | Medianoche UTC/VE, `YYYY-MM-DD`, feriado trasladado | Interpretación temporal consistente |
| USDT | Sin dato, dato viejo, reinicio offline, refresco | Estado, origen, fecha y caché propios |
| Persistencia | JSON corrupto, tipo de clave incorrecto, escritura fallida | Degradación localizada; otros datos utilizables |
| Lifecycle | Cerrar pantalla con consultas/cámara pendientes | Sin notificar a estado destruido ni filtrar recursos |
| UI | 320/360/390 dp, teclado, landscape, texto 200% | Contenido operable sin overflow |
| UI | Red fallida con caché / lectura normal de caché | Mensajes distintos y veraces |
| OCR | Texto normal sin números | Seleccionable y copiable |
| OCR | Precio repetido en dos posiciones | Dos regiones seleccionables |
| OCR | `10 20`, grupos inválidos, signo y separadores ambiguos | No fusionar ni modificar valor silenciosamente |
| OCR | Foto girada, EXIF, zoom/pan y texto inclinado | Overlay y selección alineados |
| OCR | Ticket de varias columnas, precio partido en elementos | Orden de lectura y composición coherentes |
| OCR | Precio Bs./USD, coma automática, cuatro decimales | Monto/moneda/dirección correctos y entrada editable |
| OCR nativo | Foto borrosa, sin texto, permiso denegado, galería recuperada | Recuperación comprensible |
| OCR nativo | Primera ejecución offline del APK release | Reconocimiento Latin disponible |
| Widget | Primera colocación sin caché | Invitación a abrir/cargar, sin tasas ficticias |
| Widget | Varias instancias y resize | Todas actualizadas; ajustes por instancia |
| Widget | Visitar histórico en la app | Tasa actual del launcher no cambia al histórico |
| Widget | Próxima tasa y cambio de fecha sin red | Promoción local elegible cuando se ejecute actualización; antigüedad visible |
| Widget | Refresh foreground y background concurrentes | Payload coherente; respuesta antigua no pisa datos nuevos |
| Widget | Proceso cerrado, reinicio, Doze, force-stop | Estado persistente; restricciones del sistema correctamente diferenciadas |
| Android | Build final | Release no debuggable; solo ABI `arm64-v8a` |

Las pruebas unitarias deben comprobar resultados observables. Los tests de geometría pueden usar documentos sintéticos; los tests de reconocimiento necesitan además imágenes reales y ejecución del plugin Android. Los golden tests ayudan al diseño, pero no sustituyen teclado, semántica ni launcher real.

## 10. Consideraciones de implementación y alcance

- **Riesgo técnico mayor:** selección OCR con transformaciones, gestos, orientación y texto dividido. Hacer primero una prueba funcional de geometría antes del pulido visual.
- **Dependencia transversal:** metadatos y frescura. La UI y los widgets necesitan el mismo significado de “vigente”, “guardada”, “publicada” y “sincronizada”.
- **Base Android observada:** AGP 9.0.1, Kotlin 2.3.20, minSdk fusionado 24 y targetSdk 36. Verificar compatibilidad de nuevos plugins con esa base.
- **ARM64:** los filtros están actualmente en configuración global de Android; esto también afecta debug. Planificar pruebas nativas en ARM64, o delimitar a release los filtros si después se requiere un emulador x86_64. El artefacto existente todavía necesita regeneración/verificación.
- **Secuencia de entregas:** pasos 0–3 → datos fiables; 4–5 → UI; 6–8 → OCR; 9–10 → widgets; 11 → integración. No cerrar una fase como completada si solo existe una maqueta o un test con motor nativo simulado.
- **Decisiones de producto propuestas:** inicio integrado; mantener proveedores en el orden acordado; OCR sobre foto con selección de texto y monto; widget 4×2 primero, 2×2 configurable después; periodo inicial de fondo de 60 minutos aproximados.
- **Pulido posterior:** recorte/perspectiva avanzado, OCR continuo de cámara, visualizaciones de histórico o variantes adicionales del launcher, una vez cubierto el flujo solicitado.

## 11. Instrucción de arranque para Luna

> Implementa Cuantoes siguiendo `docs/auditoria-y-plan-luna.md` y los pasos 0–11 en orden de dependencias. Empieza por los fallos de exactitud y estado antes de conectar la UI o los widgets. Usa como referencias visuales `stitch/cuantoes_bcv_principal_modo_claro_real/` y `stitch/cuantoes_bcv_principal_modo_oscuro/`, adaptando las simulaciones según la sección 5. Conserva Flutter/Material 3, Provider, DolarAPI → BCV Today → Chitty y la compatibilidad con caché existente. El OCR debe permitir seleccionar texto sobre la foto y copiarlo, además de escoger un monto y su moneda para convertir. Los widgets pedidos son del launcher Android. Documenta cada fase implementada, sus pruebas y los pendientes reales; entrega release exclusivamente ARM64 al finalizar la integración.

## 12. Referencias consultadas

Consultadas el 27/09/2026. Las versiones y ejemplos externos deben revisarse al seleccionar dependencias; los límites de plataforma se contrastan con documentación Android.

### Código y diseño local

- [`doc.md`](doc.md), [`funciones.md`](funciones.md), [`decisiones.md`](decisiones.md).
- [`stitch/`](../stitch/), [`DESIGN.md`](../stitch/sovereign_exchange/DESIGN.md).
- Paquetes resueltos locales: `google_mlkit_text_recognition-0.17.1/lib/src/text_recognizer.dart` y `android/build.gradle`; README de `camera-0.12.1` e `image_picker-1.2.3`.

### Proveedores y calendario

- [DolarAPI USD actual](https://ve.dolarapi.com/v1/dolares/oficial), [EUR actual](https://ve.dolarapi.com/v1/euros/oficial).
- [Histórico USD](https://ve.dolarapi.com/v1/historicos/dolares/oficial), [histórico EUR](https://ve.dolarapi.com/v1/historicos/euros/oficial).
- [BCV Today](https://bcv.today/api/v1/rate.json).
- [Chitty actual/próxima](https://chitty400.github.io/chitty-bcv-api/latest.json), [P2P](https://chitty400.github.io/chitty-bcv-api/p2p_history.json).
- [Calendario de Asobanca](https://asobanca.com.ve/calendario-bancario-4/), consultado en septiembre de 2026; contrastar la fuente anual SUDEBAN/BCV antes de actualizar las reglas.

### OCR y Android widgets

- [ML Kit: reconocimiento de texto Android](https://developers.google.com/ml-kit/vision/text-recognition/v2/android).
- [camera: lifecycle](https://pub.dev/packages/camera#handling-lifecycle-states).
- [image_picker: recuperación de Activity](https://pub.dev/packages/image_picker#handling-mainactivity-destruction).
- [home_widget: introducción](https://docs.page/abausg/home_widget).
- [home_widget: XML/RemoteViews](https://docs.page/abausg/home_widget/android-xml/setup).
- [home_widget: compartir datos](https://docs.page/abausg/home_widget/usage/sync-data).
- [home_widget: actualizaciones de fondo](https://docs.page/abausg/home_widget/features/background-updates).
- [Workmanager: inicio y callbacks](https://docs.page/fluttercommunity/flutter_workmanager/quickstart).
- [Android: actualización y límites de App Widgets](https://developer.android.com/develop/ui/views/appwidgets/advanced).
