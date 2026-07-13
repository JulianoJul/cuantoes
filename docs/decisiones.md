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
  - `BcvApiService.obtenerTasaHistorica(fecha)` consulta `/api/v1/history/bcv` con rango de 7 días y selecciona la tasa más reciente ≤ fecha solicitada (maneja fines de semana)
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
