# Plan de Correcciones — Cuantoes

Auditoría completa del código y documentación. Cada ítem tiene prioridad, archivo(s) afectados,
descripción del problema y solución propuesta. Marcados con `[ ]` pendiente, `[x]` completado.

---

## Bugs funcionales (prioridad alta)

### B1. Cache no se usa en fin de semana + orden de capas incorrecto

- **Archivos**: `lib/services/tasa_repository.dart`, `lib/services/bcv_cache_service.dart`
- **Bug**: `obtenerTasa()` busca `_keyFecha(hoy)` y `_keyFecha(hoy+1)`, pero la última tasa
  válida del viernes tiene clave `_keyFecha(viernes)`. En sábado/domingo el cache del viernes
  **no se encuentra**, así la app siempre llama a la red aun con cache válido.
  Además, `refrescarTasa()` usa orden API → scraper → cache, pero el orden correcto
  es API → cache → scraper.
- **Solución**: `obtenerTasa()` busca la tasa cacheada más reciente hasta hoy mediante
  `obtenerTasaMasRecienteHasta(hoy)` y valida vigencia con `_esTasaVigente`. Se eliminó
  la búsqueda por `hoy`/`hoy+1` que asumía día contiguo.
  En `refrescarTasa()`: API → si falla → cache → si falla → scraper → si falla → rethrow.
- **Estado**: [x]

### B2. Histórico no filtra por fechaEfectiva del resultado

- **Archivos**: `lib/services/bcv_api_service.dart`
- **Bug original**: `obtenerTasaHistorica` devolvía la primera fila del histórico sin
  validar su `fechaEfectiva`, por lo que una consulta podía devolver una tasa posterior
  a la fecha solicitada.
- **Solución**: Consulta una ventana de 30 días anteriores hasta el día siguiente,
  con `limit=1000`, agrupa USD y EUR por fecha efectiva, conserva solo fechas efectivas
  comunes y devuelve la mayor cuya `fechaEfectiva ≤ fecha` solicitada.
- **Estado**: [x]

### B3. fechaEfectiva no maneja feriados bancarios venezolanos

- **Archivos**: `lib/models/tasa_bcv.dart`, `scrap_bcv.py`
- **Bug**: `fechaEfectiva` solo salta sábado/domingo. En feriados (carnaval, semana santa,
  19-abr, 1-may, 24-jun, 5-jul, 24-oct, 25-dic, 31-dic, etc.) la fecha efectiva caerá en día
  no laboral sin consideración.
- **Solución**: Crear `lib/utils/feriados_ve.dart` con función
  `bool esFeriadoBancario(DateTime fecha)` basado en una lista de feriados fijos + cálculo
  de móviles (carnaval, semana santa). Usarlo en `fechaEfectiva` para saltar al siguiente
  día hábil. Replicar la misma lista en `scrap_bcv.py`.
- El selector de fecha no filtra esos días: fines de semana y feriados siguen siendo
  seleccionables; el salto solo se aplica al cálculo/resolución de la fecha efectiva.
- **Estado**: [x]

### B4. Scraper Dart siempre usa DateTime.now() como fecha

- **Archivos**: `lib/services/bcv_scraper_service.dart`
- **Bug**: `_parsear()` construye `TasaBcv(fecha: DateTime.now(), ...)` ignorando la fecha
  valor publicada por el BCV. La `fechaEfectiva` se calcula en base a "ahora" y no refleja
  la fecha real de la tasa. Si el BCV publica el viernes y se scrapea el sábado, la
  fechaEfectiva será "lunes próximo" en lugar de "viernes" o "lunes" según corresponda.
- **Solución**: Extraer la "Fecha Valor" del HTML del BCV (texto tipo
  "Fecha Valor: Miércoles, 15 Julio 2026") y parsear a `DateTime`. Cuando existe, el
  scraper Dart usa esa fecha como `fecha` y `fechaEfectiva` autoritativas. Si no se
  encuentra, usa `DateTime.now()` para `fecha` y la fecha efectiva actual como fallback.
- **Estado**: [x]

### B5. Race condition en setMoneda con USDT

- **Archivos**: `lib/viewmodels/conversor_viewmodel.dart`
- **Bug**: `setMoneda('USDT')` dispara `obtenerUsdt()` async. Si el usuario cambia rápido
  a USD antes de que llegue la respuesta, la respuesta de USDT puede llegar tarde y
  reescribir `_tasa` sin verificar que `_moneda` siga siendo `'USDT'`.
- **Solución**: Tras recibir `usdt`, verificar `if (_moneda != 'USDT') return;` antes de
  modificar `_tasa`. Idem para el flag `_cargandoUsdt`.
- **Estado**: [x]

### B6. Swap pierde precisión al truncar a 2 decimales

- **Archivos**: `lib/viewmodels/conversor_viewmodel.dart`
- **Bug**: `toggleDireccion()` copia `_resultado` (con 2 decimales) a `_entrada`. Al
  swapear dos veces, el resultado no es el original porque la precisión se perdió.
  Ej: 100 USD → 72937.57 Bs → swap → 72937.57 Bs → 100.01 USD (no 100.00).
- **Solución**: Usar `_resultadoPreciso` (4+ decimales) al copiar a `_entrada`, o mantener
  el valor original en un campo auxiliar y restaurarlo en swap inverso.
- **Estado**: [x]

### B7. scrap_bcv.py no quita puntos de miles

- **Archivos**: `scrap_bcv.py`
- **Bug**: `_parsear_tasa()` hace `replace(",", ".")` pero NO quita puntos de miles. Si el
  BCV muestra "1.234,56", el resultado "1.234.56" falla al hacer `float()`. Divergente del
  scraper Dart que sí los quita (línea 47 de `bcv_scraper_service.dart`).
- **Solución**: En `_parsear_tasa`, añadir `.replace(".", "")` antes de `replace(",", ".")`,
  igualando el comportamiento del scraper Dart.
- **Estado**: [x]

### B8. Test no mockea SharedPreferences ni HTTP

- **Archivos**: `test/widget_test.dart`
- **Bug**: El test hace `pump()` solo un frame sin mockear
  `SharedPreferences.getInstance()` ni `http.get()`. El resultado es no determinista según
  ambiente: pasa o falla por razones externas al código de la app.
- **Solución**: Setup con `TestWidgetsFlutterBinding.ensureInitialized()`,
  `SharedPreferences.setMockInitialValues({})`, mockear `http.Client` con
  `mocktail`/`http_mock_adapter`. Async pump con `pumpAndSettle()` o `pump(Duration)`.
- **Estado**: [x]

---

## Inconsistencias de documentación (prioridad media)

### D1. USDT no aparece en ningún .md pese a estar en TODO el código

- **Archivos**: `docs/ai-context.md`, `docs/doc.md`, `docs/funciones.md`, `README.md`,
  `pubspec.yaml`
- **Problema**: USDT es campo del modelo (`tasa_bcv.dart:4`), chip en UI
  (`conversor_screen.dart:80`), método `obtenerUsdt()` en API y Repository, llamado del
  ViewModel — pero ninguna doc lo menciona.
- **Solución**:
  - Actualizar `docs/funciones.md`: añadir `usdt` a `TasaBcv`, añadir `'USDT'` a
    `TasaBcv.de(moneda)`, catalogar `BcvApiService.obtenerUsdt()` y
    `TasaRepository.obtenerUsdt()`.
  - Actualizar `docs/ai-context.md:16,17,25` y `docs/doc.md:20` para incluir USDT.
  - Actualizar `pubspec.yaml` description a "Tasas de cambio según BCV (USD, EUR, USDT)".
  - Actualizar `README.md` para describir el proyecto real.
- **Estado**: [x]

### D2. Catalogación SPOT incompleta en funciones.md

- **Archivos**: `docs/funciones.md`
- **Problema**: `.clinerules:37` declara SPOT pero faltan métodos públicos:
  - `TasaBcv.fechaEfectiva` (getter)
  - `BcvCacheService.obtenerTasaPorFecha`
  - `BcvCacheService.obtenerFechasCache`
  - `TasaRepository.obtenerUsdt`
  - `TasaRepository` NOW tiene scraper inyectado — documentarlo.
  - `BcvScraperService` (no existe en el catálogo).
- **Solución**: Añadir entradas en `funciones.md` para cada uno.
- **Estado**: [x]

### D3. DEC-002 quedó desactualizado sobre rango y filtro de histórico

- **Archivos**: `docs/decisiones.md`
- **Problema original**: DEC-002 describía un rango y un filtro que no coincidían con la
  implementación anterior.
- **Solución**: DEC-002 documenta la ventana actual de 30 días, la fecha efectiva común
  para USD/EUR y la selección de la mayor fecha efectiva `≤` la solicitada.
- **Estado**: [x]

### D4. No hay ADR para USDT

- **Archivos**: `docs/decisiones.md`
- **Problema**: USDT es una feature completa (chip, método en API, endpoint Binance,
  llamada en ViewModel) sin ADR que la justifique.
- **Solución**: Añadir DEC-005 "Soporte USDT vía Binance P2P" describiendo el endpoint
  `/binance/realtime_ves`, el flag `_cargandoUsdt`, y la UX (oculta selector de fecha).
- **Estado**: [x]

### D5. scrap_bcv.py no referenciado en ningún .md

- **Archivos**: `docs/ai-context.md`, `docs/doc.md`, `docs/decisiones.md`
- **Problema**: El script Python Selenium existe pero ninguna doc lo menciona. Tampoco
  explica que es alternativa al scraper Dart cuando BCV bloquea HTTP.
- **Solución**: Añadir sección en `ai-context.md` y `doc.md`. Documentar dependencias
  (`selenium`, Firefox, geckodriver) y cómo ejecutarlo
  (`/tmp/opencode/bcv_scraper/bin/python3 scrap_bcv.py`).
- **Estado**: [x]

### D6. Makefile y .clinerules NO corresponden a este proyecto

- **Archivos**: `Makefile`, `.clinerules`
- **Problema**: El Makefile tiene targets `combine`, `serve`, `electron-*`, `tauri-*`,
  `wails-*` que referencian archivos inexistentes (`frontend/index.html`, `app.go`,
  `main.go`, `wails.json`, `Tablas8.sql`, `go.mod`). `.clinerules:4` describes "SPA con
  sql.js y Electron" pero el proyecto es Flutter. No hay `flutter build/test/analyze`.
- **Solución**:
  - Reescribir Makefile con targets Flutter: `analyze`, `test`, `build-apk`,
    `build-apk-debug`, `run`, `pub-get`, `clean`.
  - Actualizar `.clinerules` para describir Flutter/Provider/ChangeNotifier en lugar de
    la SPA Wails/SQL.js/Electron.
- **Estado**: [x]

### D7. README es boilerplate default

- **Archivos**: `README.md`
- **Problema**: Es la plantilla de `flutter create` sin personalizar. No describe USD/EUR/
  USDT, ni el flujo API→scraping→cache, ni cómo correrlo.
- **Solución**: Reescribir README con: descripción, dependencias (incluyendo
  `scrap_bcv.py`), comandos (`flutter run`, `flutter analyze`, `flutter build apk`), y
  arquitectura resumida (link a `docs/`).
- **Estado**: [x]

---

## Código muerto y dependencias (prioridad media)

### C1. fl_chart declarado pero no usado

- **Archivos**: `pubspec.yaml`
- **Problema**: `fl_chart ^0.69.0` (línea 20) no se importa en ningún `.dart`. Aumenta
  bundle y superficie de actualizaciones.
- **Solución**: Eliminar la línea `fl_chart: ^0.69.0` del `pubspec.yaml` y ejecutar
  `flutter pub get`.
- **Estado**: [x]

### C2. BcvCacheService.obtenerFechasCache() no se invoca

- **Archivos**: `lib/services/bcv_cache_service.dart`
- **Problema**: Método público sin consumidores en el proyecto.
- **Solución**: Eliminarlo, o usarlo en un futuro feature de "lista de fechas cacheadas"
  para el selector de fecha. Si se elimina, quitarlo también de `funciones.md`.
- **Estado**: [x]

### C3. Variable redundante en _keyFecha

- **Archivos**: `lib/services/bcv_cache_service.dart`
- **Problema**: `final d = fecha;` en línea 9 — `d == fecha`, code smell.
- **Solución**: Usar `fecha` directamente.
- **Estado**: [x]

---

## Mejoras funcionales (prioridad baja)

### M1. Fecha Valor como fecha efectiva del scraper

- **Archivos**: `lib/services/bcv_scraper_service.dart`, `lib/models/tasa_bcv.dart`
- **Implementación**: `BcvScraperService` extrae "Fecha Valor" y, cuando es válida, la usa
  directamente como `fecha` y `fechaEfectiva` de `TasaBcv`. No existe un campo separado
  `fechaValorBcv` en el modelo; el script Python conserva el texto en `fecha_valor_bcv`.
- **Estado**: [x]

### M2. Vista de variación porcentual

- **Archivos**: `lib/viewmodels/conversor_viewmodel.dart`, `lib/screens/conversor_screen.dart`
- **Mejora**: Mostrar "▲ +0.61%" o "▼ -0.20%" junto a la tasa actual o histórica,
  comparando con la tasa de la fecha efectiva inmediatamente anterior mediante
  `obtenerTasaAnterior`. No aplica a USDT.
- **Estado**: [x]

### M3. Calendario resalta fechas con cache disponible

- **Archivos**: `lib/screens/conversor_screen.dart`, `lib/services/bcv_cache_service.dart`
- **Mejora**: Usar `obtenerFechasCache()` (si no se elimina en C2) para marcar en el
  `showDatePicker` los días con cache disponible (selectableDayPredicate + estilo).
- **Estado**: [x]

### M4. Lints de "cero hardcodeo" no activados

- **Archivos**: `analysis_options.yaml`
- **Mejora**: `.clinerules:13` declara "Cero hardcodeo" pero los lints correspondientes
  (`avoid_hardcoded_colors`, `avoid_renaming_method_parameters`, etc.) no están activados.
- **Solución**: Descomentar las reglas en `analysis_options.yaml` o añadir las
  recomendadas.
- **Estado**: [x]

---

## Orden de ejecución propuesto

1. **Bugs críticos primero**: B1 (cache + orden API→cache→scraper) → B3 (feriados) → B2 (filtro
   histórico) → B4 (fecha scraper) → B5 (race USDT) → B7 (Python miles).
2. **Code cleanup**: C1 (fl_chart) → C2 (método muerto) → C3 (var redundante).
3. **Docs sync**: D1 (USDT) → D2 (SPOT) → D3/D4 (ADR) → D5 (scrap_bcv.py) → D6 (Makefile/
   .clinerules) → D7 (README).
4. **Tests**: B8 (mock setup) → añadir tests para ViewModel + Repository.
5. **Mejoras**: M1 → M2 → M3 → M4.

---

## Estado global

- Total de issues: **20** (8 bugs + 7 docs + 3 code + 4 mejoras + 2 nuevas features)
- Completados: **20**
- Pendientes: **0**

### Features adicionales implementadas
- **F1**: Resolución de una fecha seleccionada a la mayor tasa efectiva `≤` esa fecha,
  sin cambiar visualmente la fecha elegida; la tarjeta muestra la fecha aplicada (DEC-007)
- **F2**: Variación porcentual para tasas actuales e históricas frente a la fecha efectiva
  inmediatamente anterior (DEC-008)

## Invariantes actuales
- El calendario permite seleccionar fines de semana y feriados.
- La fecha seleccionada se conserva visualmente; la tasa se resuelve con la mayor
  `fechaEfectiva ≤` la fecha solicitada y la tarjeta muestra la fecha efectiva aplicada.
- La variación se calcula para USD/EUR actuales e históricos usando la tasa efectiva
  inmediatamente anterior; no se calcula para USDT.
- La consulta de tasa actual en cache excluye `fechaEfectiva` futuras; esas entradas no
  pueden devolverse como tasa actual.
- Los timestamps Rafnix sin zona horaria se interpretan como UTC y se convierten a
  Venezuela (UTC-4) antes del corte de las 14:00.
- El scraper Dart trata "Fecha Valor" como autoritativa cuando está presente.
- El histórico consulta USD y EUR con una fecha efectiva común.
