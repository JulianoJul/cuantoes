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
- **Solución**: `obtenerTasa()` debe buscar la clave de cache más reciente (con
  `_cache.obtenerTasa()` que ya devuelve la mayor lexicográficamente), y validar vigencia
  con `_esTasaVigente`. Eliminar la búsqueda por `hoy`/`hoy+1` que asume día contiguo.
  En `refrescarTasa()`: API → si falla → cache → si falla → scraper → si falla → rethrow.
- **Estado**: [x]

### B2. Histórico no filtra por fechaEfectiva del resultado

- **Archivos**: `lib/services/bcv_api_service.dart`
- **Bug**: `obtenerTasaHistorica` consulta `[fecha-1, fecha+2]` con `order=desc&limit=1`
  y devuelve `currencies.first` sin validar que su `fechaEfectiva` coincida con la fecha
  solicitada. Pedir "miércoles" puede devolver la tasa del "viernes" o "lunes siguiente".
- **Solución**: Rango ampliado a 7 días, limit=10, iterar resultados en orden DESC
  y devolver la primera cuya `fechaEfectiva <= fecha` solicitada.
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
- **Estado**: [x]

### B4. Scraper Dart siempre usa DateTime.now() como fecha

- **Archivos**: `lib/services/bcv_scraper_service.dart`
- **Bug**: `_parsear()` construye `TasaBcv(fecha: DateTime.now(), ...)` ignorando la fecha
  valor publicada por el BCV. La `fechaEfectiva` se calcula en base a "ahora" y no refleja
  la fecha real de la tasa. Si el BCV publica el viernes y se scrapea el sábado, la
  fechaEfectiva será "lunes próximo" en lugar de "viernes" o "lunes" según corresponda.
- **Solución**: Extraer la "Fecha Valor" del HTML del BCV (texto tipo
  "Fecha Valor: Miércoles, 15 Julio 2026") y parsear a `DateTime`. Usar esa fecha como
  `fecha` del `TasaBcv`. Fallback a `DateTime.now()` si no se encuentra.
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

### D3. DEC-002 miente sobre rango y filtro de histórico

- **Archivos**: `docs/decisiones.md`
- **Problema**: Dice "rango de 7 días y selecciona la tasa más reciente ≤ fecha solicitada"
  — el código realmente usa `[fecha-1, fecha+2]` (4 días) y no hay filtro `≤ fecha`.
- **Solución**: Actualizar DEC-002 o crear DEC-005 describiendo el query ampliado y la
  futura lógica de filtrado (cuando se arregle B2).
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

### M1. fechaHoraValorBcv en el modelo

- **Archivos**: `lib/models/tasa_bcv.dart`
- **Mejora**: Añadir campo `DateTime? fechaValorBcv` opcional para preservar la fecha real
  publicada por el BCV (no la derivada por `fechaEfectiva`). Útil cuando el scraper extrae
  "Fecha Valor: Miércoles, 15 Julio 2026" del HTML.
- **Estado**: [x]

### M2. Vista de variación porcentual

- **Archivos**: `lib/viewmodels/conversor_viewmodel.dart`, `lib/screens/conversor_screen.dart`
- **Mejora**: Mostrar "▲ +0.61%" o "▼ -0.20%" junto a la tasa actual, comparando con la
  tasa del día anterior (cargada vía `obtenerTasaHistorica(hoy-1)` o cache del día previo).
  Solo para vista de hoy/mañana.
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
- **F1**: Fallback automático a fecha anterior en selector histórico (DEC-007)
- **F2**: Variación porcentual vs día anterior (DEC-008)
