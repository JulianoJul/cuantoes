# Architecture Decision Records (ADR)

## DEC-001: API principal + scraping fallback + cache

- **Origen:** `[Instrucción Explícita del Usuario]`
- **Contexto y Causa:** App para tasa de cambio USD/EUR↔VES del BCV. Necesita funcionar incluso sin conexión o si una fuente falla.
- **Decisión:** Tres capas de obtención de datos:
  1. API REST: `dolar-vzla.rafnixg.dev/api/v1/bcv/realtime` (principal)
  2. Cache con `shared_preferences` (tasas por fecha efectiva)
  3. Scraping directo de `bcv.org.ve` usando `http` + `html` (fallback)
  - `obtenerTasa()` intenta primero una tasa cacheada cuya `fechaEfectiva` no sea
    posterior a hoy en Venezuela.
  - `refrescarTasa()` fuerza el orden API → cache → scraper.
  - Una entrada futura puede conservarse para mostrar la próxima tasa disponible,
    pero nunca se devuelve como tasa actual.
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
  - DatePicker para seleccionar fecha histórica; no bloquea fines de semana ni feriados
  - `BcvApiService.obtenerTasaHistorica(fecha)` consulta `/api/v1/history/bcv` para USD y EUR en la ventana `[fecha-30 días, fecha+1 día]` (`limit=1000`, `order=desc`), agrupa por `fechaEfectiva` y selecciona la mayor fecha efectiva común cuya `fechaEfectiva ≤ fecha` solicitada
  - La tasa histórica de USD y EUR siempre proviene de una misma fecha efectiva común
  - `flutter_localizations` para calendario en español
- **Impacto:** ViewModel gana `_moneda` y `_fechaSeleccionada`. UI agrega tabs y selector de fecha. La fecha elegida permanece visible; la tarjeta muestra por separado la `fechaEfectiva` aplicada.

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
  - El scraper Dart integrado da prioridad a "Fecha Valor" del HTML: cuando está presente, fija `fecha` y `fechaEfectiva`; si no aparece, usa la fecha efectiva actual
  - `scrap_bcv.py` conserva el texto encontrado en `fecha_valor_bcv` y produce un JSON compatible para uso externo; no está integrado en el pipeline Flutter
- **Impacto:** Archivo `scrap_bcv.py` en raíz. Documentado en docs como alternativa.

---

## DEC-007: Fecha seleccionada y fecha efectiva aplicada

- **Origen:** `[Solicitud del usuario tras probar la app]`
- **Contexto y Causa:** Una fecha seleccionada puede ser fin de semana, feriado o no tener una entrada exacta, aunque sí exista una tasa efectiva anterior aplicable.
- **Decisión:**
  - `cargarTasa()` con `_fechaSeleccionada` conserva la fecha elegida, incluidos fines de semana y feriados.
  - `TasaRepository.obtenerTasaHistorica()` busca primero cache exacta, luego la mayor `fechaEfectiva ≤ fecha` solicitada mediante API y finalmente la tasa cacheada anterior disponible.
  - Si la tasa aplicada es anterior a la fecha solicitada, `_fechaSeleccionada` no se reemplaza.
  - `fechaEfectivaAplicada` expone la fecha real de la tasa mostrada y la tarjeta la presenta como "Tasa aplicada".
- **Impacto:** El calendario refleja la intención del usuario y la tarjeta distingue fecha solicitada de fecha efectiva aplicada. Si no existe una tasa elegible, se muestra error en vez de sustituirla por la tasa viva.

---

## DEC-008: Variación porcentual respecto al día anterior

- **Origen:** `[Solicitud del usuario]`
- **Contexto y Causa:** No había indicación visual de si la tasa subió o bajó respecto al día anterior.
- **Decisión:**
  - `ConversorViewmodel.variacion` (`double?`): se calcula al cargar/refrescar una tasa actual o histórica
  - `_calcularVariacion()`: obtiene `obtenerTasaAnterior(actual.fechaEfectiva)`, que resuelve la fecha efectiva inmediatamente anterior, y calcula `((actual - anterior) / anterior) * 100`
  - Funciona para USD y EUR tanto con fecha seleccionada como sin ella; no se calcula para USDT
  - No bloquea la UI si falla (variación queda null)
- **Impacto:** Nueva propiedad `variacion` en ViewModel. UI muestra ▲/▼ + porcentaje en la línea de la moneda correspondiente.

---

## DEC-009: fechaEfectiva como campo almacenado con timezone Venezuela

- **Origen:** `[Bug reportado por usuario]`
- **Contexto y Causa:** La API realtime (`dolar-vzla.rafnixg.dev`) devuelve timestamps del proveedor que pueden no incluir zona horaria. Interpretar sus componentes sin zona como hora local del dispositivo desplaza el corte de las 14:00 en Venezuela.
- **Decisión:**
  - `fechaEfectiva` es un campo `final DateTime` almacenado; los servicios y factories le entregan el valor normalizado sin recalcularlo mediante un getter.
  - Factory `TasaBcv.actual()` para tasas basadas en la hora actual (usa hora VE)
  - `calcularFechaEfectiva(fecha)` para fechas de referencia que requieren aplicar el corte y el siguiente día hábil
  - En `BcvApiService`, los timestamps Rafnix sin zona se interpretan como componentes UTC; luego se convierten a Venezuela (UTC-4) antes de aplicar el corte de las 14:00. Los timestamps con zona también se normalizan a UTC antes de esa conversión.
  - USD y EUR realtime deben resolver a la misma `fechaEfectiva`; si no, la respuesta se rechaza.
  - `fromJson` con retrocompatibilidad: si no hay `fecha_efectiva` en JSON, se computa desde `fecha`
  - `_esTasaVigente` en `TasaRepository` también usa `ahoraVenezuela()`
- **Alternativas evaluadas:**
  - Clamp del getter con `DateTime.now()` — descartado: getter impuro, dificulta testing
  - Interpretar timestamps sin zona con la zona del dispositivo — descartado: el contrato de Rafnix los trata como UTC
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

---

## DEC-011: Heurística para evitar adelanto prematuro de fechaEfectiva

- **Origen:** `[Bug reportado por usuario]`
- **Contexto y Causa:** Si el BCV se retrasa en actualizar la tasa después de las 2:00 PM, la regla general de `hora >= 14 -> próximo día hábil` provocaba que la app mostrara que la tasa (aún no actualizada) pertenecía a "mañana".
- **Decisión:**
  - En `TasaRepository.refrescarTasa()`, después de obtener la nueva tasa (ya sea por API o scraping), se comparan sus valores USD y EUR con los de la última tasa almacenada en caché.
  - Si ambas diferencias son menores a `0.00001` (es decir, el BCV no ha actualizado los valores), se descarta el avance de fecha y se conserva la `fechaEfectiva` de la tasa en caché.
  - Se implementó esto en un método interno `_aplicarHeuristicaFecha(TasaBcv nuevaTasa)`.
  - La búsqueda de tasa actual solo considera entradas con `fechaEfectiva ≤ hoy` en Venezuela. Las entradas futuras se conservan para `obtenerTasaSiguiente()`, pero `_tasaActualPostRefresh()` nunca las devuelve como actuales.
- **Impacto:** La fecha mostrada en la UI se mantiene fiel a la realidad incluso si hay retrasos en la publicación del BCV por la tarde o si la API entrega anticipadamente una tasa futura.

---

## DEC-012: Calendario limitado a la próxima tasa publicada

- **Origen:** `[Solicitud del usuario]`
- **Contexto y Causa:** El calendario permitía seleccionar mañana aunque su tasa aún no estuviera publicada, mostrando la tasa de hoy como aplicada o un error según el caso.
- **Decisión:**
  - `ConversorViewmodel.fechaTasaSiguiente` expone la `fechaEfectiva` de la próxima tasa cacheada (`TasaRepository.obtenerTasaSiguiente()`), o `null` si no existe.
  - `ConversorViewmodel.fechaMaximaSeleccionable` devuelve esa fecha si es futura, o hoy en Venezuela en caso contrario.
  - `_abrirCalendario` usa `fechaMaximaSeleccionable` como `lastDate` del DatePicker.
- **Impacto:** No se pueden elegir fechas posteriores a la próxima tasa publicada; los fines de semana y feriados ya transcurridos siguen seleccionables.

---

## DEC-013: Histórico combina API y caché por fecha efectiva más cercana

- **Origen:** `[Bug reportado por usuario]`
- **Contexto y Causa:** El histórico de la API puede estar incompleto (por ejemplo, USD sin datos del 10 y 11 mientras EUR sí los tiene). `obtenerTasaHistorica()` devolvía el resultado de la API aunque la caché de tiempo real tuviera una fecha efectiva más cercana a la solicitada; al elegir el 11 se aplicaba el 9 en vez del 10.
- **Decisión:**
  - `obtenerTasaHistorica()` y `obtenerTasaAnterior()` comparan el resultado de la API con la tasa cacheada más reciente anterior al límite y devuelven la de mayor `fechaEfectiva`.
  - Si la API falla, se usa la cache previa (antes `obtenerTasaAnterior()` devolvía `null` en ese caso).
- **Impacto:** "Tasa aplicada" y la variación porcentual usan la fecha efectiva más cercana disponible, sin importar la fuente.
