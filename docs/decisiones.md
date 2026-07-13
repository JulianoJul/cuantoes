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
