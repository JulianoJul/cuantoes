# Architecture Decision Records (ADR)

## DEC-001: Flutter con scraping + API + cache

- **Origen:** `[Instrucción Explícita del Usuario]`
- **Contexto y Causa:** App para tasa de cambio USD/VES del BCV. Necesita funcionar incluso sin conexión o si el BCV cambia su sitio.
- **Decisión:** Tres capas de obtención de datos:
  1. Scraping directo de `bcv.org.ve` usando `http` + `html` con selectores `#dolar`, `#euro`
  2. API fallback: `dolar-vzla.rafnixg.dev/api/v1/bcv/realtime`
  3. Cache con `shared_preferences` (última tasa guardada)
- **Alternativas evaluadas:**
  - Solo API — descartado: dependencia de terceros
  - Solo scraping — descartado: frágil si el BCV cambia el HTML
  - Solo cache — descartado: datos desactualizados
- **Impacto:** `TasaRepository` orquesta el flujo con try/catch encadenados.
