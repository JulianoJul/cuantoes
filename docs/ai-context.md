# Contexto activo de Cuantoes

## Arquitectura y líneas rojas

- App Flutter/Material 3 con Provider. Mantener el `ConversorViewmodel` como autoridad de conversión.
- Tasas oficiales en cascada: **DolarAPI → BCV Today → Chitty BCV → caché local**. No reintroducir scrapers HTML/Python.
- USD/EUR son tasas oficiales `TasaBcv`; USDT es referencia P2P independiente `CotizacionUsdt`, con fuente, fecha y caché propias.
- `ResultadoTasa` distingue datos recibidos por red, caché y estado de frescura. No mostrar un dato almacenado como recién actualizado.
- OCR Latin de ML Kit es local al dispositivo. Conservar geometría e identidad de cada región; una transferencia debe confirmar monto, moneda y sentido antes de alterar la conversión.
- Los widgets del launcher son Android nativo `RemoteViews`/`AppWidgetProvider`. Flutter solo comparte snapshot y programa refresco; no usar Flutter embebido en el launcher.
- Compartir parsing/fechas por utilidades existentes; no replicar reglas de días hábiles fuera de `utils/feriados_ve.dart`.
- Mantener pruebas sin red/dispositivo para modelos y repositorio. Las pruebas físicas de OCR y launcher se documentan como pendientes, no como cubiertas por tests Flutter.
- No hacer commit/push salvo petición explícita.

## Documentación de referencia

- `docs/auditoria-y-plan-luna.md`: línea base, criterios y estado de implementación.
- `docs/doc.md`: arquitectura y flujo actuales.
- `docs/funciones.md`: catálogo de APIs existentes.
- `docs/decisiones.md`: ADRs; DEC-015 es la decisión vigente de proveedores JSON.
