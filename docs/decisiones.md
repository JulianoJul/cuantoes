# Architecture Decision Records (ADR)

## DEC-001: API principal + scraping fallback + cache

- **Origen:** `[Instrucción Explícita del Usuario]`
- **Contexto y Causa:** App para tasa de cambio USD/EUR↔VES del BCV. Necesita funcionar incluso sin conexión o si una fuente falla.
- **Decisión:** Tres capas de obtención de datos:
  1. API REST: `dolar-vzla.rafnixg.dev/api/v1/bcv/realtime` (principal)
  2. Scraping directo de `bcv.org.ve` usando `http` + `html` (fallback)
  3. Cache con `shared_preferences` (última tasa guardada)
- **Alternativas evaluadas:**
  - Solo API — descartado: dependencia de terceros
  - Solo scraping — descartado: frágil si el BCV cambia el HTML
  - Solo cache — descartado: datos desactualizados
- **Impacto:** `TasaRepository` orquesta el flujo con try/catch encadenados.

---

## DEC-002: Soporte EUR + histórico con calendario

- **Origen:** `[Instrucción Explícita del Usuario]`
- **Contexto y Causa:** Se requería conversión no solo de USD sino también EUR, y poder consultar tasas de días anteriores.
- **Decisión:**
  - Selector de moneda (USD/EUR) con ChoiceChips
  - DatePicker para seleccionar fecha histórica
  - `BcvApiService.obtenerTasaHistorica(fecha)` consulta `/api/v1/history/bcv` con rango de 7 días (`[fecha-7, fecha+3]`, limit=10, order=desc) y selecciona la primera tasa cuya `fechaEfectiva ≤ fecha` solicitada (maneja fines de semana y feriados)
  - `flutter_localizations` para calendario en español
- **Impacto:** ViewModel gana `_moneda` y `_fechaSeleccionada`. UI agrega tabs y selector de fecha.

---

## DEC-003: TextEditingController en ViewModel para swap

- **Origen:** `[Bug reportado por usuario]`
- **Contexto y Causa:** Al presionar swap, el ViewModel actualizaba `_entrada` con el resultado pero el TextField no reflejaba el cambio porque maneja su propio estado interno.
- **Decisión:** Mover `TextEditingController` al ViewModel. `toggleDireccion()` actualiza tanto `_entrada` como `controller.text`. Se descarta en `dispose()`.
- **Impacto:** ViewModel importa `package:flutter/widgets.dart`. Screen usa `controller: vm.entradaController`.

---

## DEC-004: Icono $ generado con ImageMagick

- **Origen:** `[Instrucción Explícita del Usuario]`
- **Contexto y Causa:** El icono por defecto de Flutter no representaba la app de tasa de cambio.
- **Decisión:** Generar icono con ImageMagick: fondo índigo (`#3f51b5`), símbolo $ blanco (DejaVu-Sans-Bold, puntosize 260 para safe zone adaptativa).
- **Impacto:** PNG generados para todos los mipmap densities + foreground/background para adaptive icons (Android 8+).

---

## DEC-005: Soporte USDT vía Binance P2P

- **Origen:** `[Instrucción Explícita del Usuario]`
- **Contexto y Causa:** Se requería conversión USDT↔VES además de USD/EUR. USDT no lo publica el BCV, por lo que se usa un fuente distinta.
- **Decisión:**
  - Nuevo método `BcvApiService.obtenerUsdt()` que consulta `/api/v1/binance/realtime_ves` y extrae `median_price`
  - TasaBcv.usdt se actualiza bajo demanda: solo cuando el usuario selecciona USDT
  - Flag `_cargandoUsdt` + verificación `_moneda != 'USDT'` post-respuesta para evitar race condition
  - El selector de fecha se deshabilita en modo USDT (no hay histórico de Binance)
- **Impacto:** TasaBcv gana campo `usdt`. ViewModel gana `obtenerUsdt`, `_cargandoUsdt`, `entradaBloqueada`. UI añade chip USDT y deshabilita calendario.

---

## DEC-006: Scraping Python con Firefox como alternativa al scraper Dart

- **Origen:** `[Instrucción Explícita del Usuario]`
- **Contexto y Causa:** El BCV renderiza las tasas con JavaScript. El scraper Dart (HTTP+HTML) no puede ejecutar JS y falla si el BCV bloquea requests HTTP simples.
- **Decisión:**
  - Script `scrap_bcv.py` con Selenium + Firefox headless para scraping JS-rendered
  - Misma lógica de `fechaEfectiva` (≥14h + salto findes/feriados)
  - Extrae "Fecha Valor" del HTML renderizado
  - Output JSON compatible con el modelo Dart
  - No integrado en el pipeline de Flutter; se ejecuta manualmente o vía script externo
- **Impacto:** Archivo `scrap_bcv.py` en raíz. Documentado en docs como alternativa.

---

## DEC-007: Fallback a fecha anterior en selector histórico

- **Origen:** `[Solicitud del usuario tras probar la app]`
- **Contexto y Causa:** El usuario seleccionaba una fecha (ej: 14/07) y la API/cache no tenían datos para ese día exacto, mostrando error. El usuario pedía que el calendario muestre automáticamente la fecha anterior con datos disponibles.
- **Decisión:**
  - `cargarTasa()` con `_fechaSeleccionada`: primero intenta `obtenerTasaHistorica`; si falla (null), hace fallback a `obtenerTasa()` (tasa viva) sin requerir match exacto de fecha
  - Si la `fechaEfectiva` de la tasa obtenida es anterior a la seleccionada por el usuario, `_fechaSeleccionada` se actualiza a esa fecha, reflejando en el calendario los datos reales
  - No se actualiza si la fecha efectiva es igual o posterior (evita mostrar "Mañana" cuando el usuario seleccionó "Hoy")
- **Impacto:** Simplifica `cargarTasa()` eliminando la comparación `sel == ef`. El selector de fecha siempre muestra la fecha de los datos que se están visualizando.

---

## DEC-008: Variación porcentual respecto al día anterior

- **Origen:** `[Solicitud del usuario]`
- **Contexto y Causa:** No había indicación visual de si la tasa subió o bajó respecto al día anterior.
- **Decisión:**
  - `ConversorViewmodel.variacion` (`double?`): se calcula al cargar/refrescar tasa actual
  - `_calcularVariacion()`: obtiene tasa del día anterior vía `obtenerTasaHistorica(hoy-1)`, calcula `((actual - anterior) / anterior) * 100`
  - Solo se calcula para tasa actual (sin fecha seleccionada), no para USDT
  - No bloquea la UI si falla (variación queda null)
- **Impacto:** Nueva propiedad `variacion` en ViewModel. UI muestra ▲/▼ + porcentaje en la línea de tasa correspondiente.

---

## DEC-009: fechaEfectiva como campo almacenado con timezone Venezuela

- **Origen:** `[Bug reportado por usuario]`
- **Contexto y Causa:** La API realtime (`dolar-vzla.rafnixg.dev`) devuelve el timestamp del servidor (UTC), no la hora de publicación del BCV. El getter `fechaEfectiva` usaba `fecha.hour >= 14` con ese timestamp UTC, causando que a mediodía en Venezuela (16:XX UTC) la app mostrara la tasa del día siguiente (que aún no existía).
- **Decisión:**
  - `fechaEfectiva` pasa de getter computado a campo `final DateTime` almacenado
  - Se calcula una sola vez al crear el modelo, usando `DateTime.now().toUtc() - 4h` (hora Venezuela, sin DST)
  - Factory `TasaBcv.actual()` para tasas en tiempo real (usa hora VE)
  - `calcularFechaEfectiva(fecha)` para tasas históricas (usa la fecha del registro)
  - `fromJson` con retrocompatibilidad: si no hay `fecha_efectiva` en JSON, se computa desde `fecha`
  - `_esTasaVigente` en `TasaRepository` también usa `ahoraVenezuela()`
- **Alternativas evaluadas:**
  - Clamp del getter con `DateTime.now()` — descartado: getter impuro, dificulta testing
  - Parsear timezone del servidor API — descartado: frágil, la API no documenta su timezone
- **Impacto:** `TasaBcv` gana campo `fechaEfectiva` y factory `.actual()`. `feriados_ve.dart` gana 3 funciones (`ahoraVenezuela`, `calcularFechaEfectiva`, `fechaEfectivaActual`). Cache persiste `fecha_efectiva` en JSON. Retrocompatible con cache antiguo.

---

## DEC-010: Menú lateral, Modo Oscuro y Coma Automática

- **Origen:** `[Instrucción Explícita del Usuario]`
- **Contexto y Causa:** Se requería un menú lateral (Drawer) para albergar opciones secundarias sin sobrecargar la UI principal. Específicamente, se pedía:
  1. Toggle de "Modo Coma Automática": un formateador de entrada que simule el desplazamiento de centavos (ej: al teclear `1` -> `0,01`, luego `5` -> `0,15`, luego `0` -> `1,50`).
  2. Toggle de Modo Oscuro.
  3. Mover la etiqueta "Datos desde [API/BCV directo]" al menú lateral para limpiar la pantalla de inicio.
- **Decisión:**
  - Implementar `SettingsProvider` (ChangeNotifier) para gestionar y persistir las configuraciones en `SharedPreferences`.
  - Registrar `ChangeNotifierProvider<SettingsProvider>` a nivel global en `main.dart` envolviendo la app para permitir cambios de tema dinámicos con `themeMode`.
  - Crear `AutomaticCommaFormatter` (TextInputFormatter) para aplicar la lógica de desplazamiento de comas cuando el modo está activo.
  - Diseñar el menú (`Drawer`) en `ConversorScreen` con los interruptores y el indicador de origen de datos en el footer.
- **Impacto:** La UI es más limpia y moderna. Los tests se adaptaron para inicializar `SettingsProvider` automáticamente dentro de `CuantoesApp`.
