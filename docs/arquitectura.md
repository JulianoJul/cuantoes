# Arquitectura activa de Cuantoes

Actualizado: 28 de septiembre de 2026.

Este documento es la fuente de verdad técnica del proyecto. Las razones de las
decisiones están en [`decisiones.md`](decisiones.md) y las comprobaciones
pendientes en [`validacion.md`](validacion.md).

## Reglas de desarrollo

- Flutter/Material 3 con `Provider`; `ConversorViewmodel` es la autoridad del
  estado de conversión.
- Separar UI, estado, acceso a datos y adaptadores nativos.
- Reutilizar las APIs descritas aquí antes de crear otra función equivalente.
- USD/EUR son tasas oficiales. USDT es una referencia P2P independiente y no
  debe contaminar fechas, fuente, caché ni widgets oficiales.
- `lib/utils/feriados_ve.dart` es la única fuente local de reglas de días
  hábiles. Las fechas se interpretan en Venezuela (UTC-4).
- Una fecha solicitada y la fecha efectiva aplicada son conceptos distintos.
- Un valor de caché nunca debe presentarse como recién validado por internet.
- OCR y widgets cruzan límites nativos: los tests Dart no sustituyen una prueba
  en Android real.
- No hacer commit ni push salvo petición explícita.

## Stack

| Área | Implementación |
|---|---|
| UI y estado | Flutter, Material 3, Provider/ChangeNotifier |
| HTTP | `http` sobre proveedores JSON |
| Persistencia | `shared_preferences` |
| Formato | `intl`, locale español |
| OCR | ML Kit Latin local + cámara/selector de imágenes |
| Widgets | `AppWidgetProvider`/`RemoteViews`, `home_widget`, WorkManager |
| Android | ARM64, minSdk fusionado 24, targetSdk 36 |

## Flujo de tasas

```text
ConversorViewmodel
  └─ TasaRepository
       ├─ DolarAPI
       ├─ BCV Today
       ├─ Chitty BCV
       └─ caché local
```

- `obtenerTasaConEstado()` puede usar una tasa aplicable guardada y conserva
  metadatos de origen, validación y frescura.
- `refrescarTasaConEstado()` intenta DolarAPI → BCV Today → Chitty BCV → caché.
- Una tasa futura se guarda como próxima, pero nunca se devuelve como actual.
- El histórico elige la mayor `fechaEfectiva ≤ fecha solicitada` entre proveedor
  y caché. Se pueden solicitar fines de semana y feriados.
- El calendario llega hasta hoy o hasta la próxima tasa ya publicada.
- USDT se obtiene y persiste como `CotizacionUsdt`, con TTL y errores propios.

## Mapa del código

```text
lib/
├── main.dart
├── models/        # contratos de dominio y persistencia
├── services/      # proveedores, repositorio, OCR, ajustes y widgets
├── viewmodels/    # estado y operaciones de conversión
├── screens/       # composición, navegación y flujos de UI
└── utils/         # reglas puras, formato y mapeo de coordenadas

android/app/src/main/
├── kotlin/.../MainActivity.kt         # recorte 4:3 y orientación de cámara
├── kotlin/.../BcvWidgetProvider.kt    # widgets nativos
├── res/layout/                         # RemoteViews
└── res/xml/                            # metadata de widgets
```

## Contratos principales

### Modelos

| Tipo | Responsabilidad |
|---|---|
| `TasaBcv` | USD/EUR oficiales, origen y fecha efectiva |
| `ResultadoTasa` | tasa más modo de obtención, validación y frescura |
| `CotizacionUsdt` | referencia P2P separada, con origen y fechas propias |
| `DocumentoOcr` / `RegionOcr` | texto reconocido, identidad y geometría |
| `TransferenciaOcr` | monto y moneda confirmados antes de convertir |
| `WidgetSnapshot` | payload versionado para las RemoteViews |

### Servicios y repositorio

| API | Responsabilidad |
|---|---|
| `BcvProvider` | contrato común para fuentes de tasas |
| `DolarApiService` | fuente principal actual e histórica USD/EUR |
| `BcvTodayService` | primer fallback con snapshots diarios |
| `ChittyBcvService` | segundo fallback y fuente P2P de USDT |
| `BcvCacheService` | tasas por fecha, próxima tasa, USDT y metadatos |
| `TasaRepository` | selección de proveedor, caché, histórico y frescura |
| `OcrService.reconocerDocumento()` | archivo → ML Kit → documento con regiones |
| `HomeWidgetService.publicar()` | resultado actual → snapshot → widgets |
| `WidgetBackgroundRefresh` | programa/cancela WorkManager según instancias |
| `SettingsProvider` | tema, coma automática y moneda del widget compacto |

### ViewModel

`ConversorViewmodel` expone, entre otros:

- `cargarTasa()`, `refrescarTasa()` y `seleccionarFecha()`.
- `setMoneda()`, `setEntrada()`, `convertir()` y `toggleDireccion()`.
- `aplicarMontoEscaneado()` para sincronizar monto, moneda, dirección,
  controlador de texto y estado de coma automática.
- `fechaEfectivaAplicada`, `fechaTasaSiguiente` y
  `fechaMaximaSeleccionable`.
- `labelOrigen` y `labelDestino`, basados en
  `utils/currency_labels.dart`.

### Utilidades compartidas

| API | Uso |
|---|---|
| `ahoraVenezuela()` | reloj normalizado a UTC-4 |
| `esFeriadoBancario()` / `proximoDiaHabil()` | calendario bancario |
| `extraerNumeros()` / `parsearNumero()` | candidatos OCR, incluso unidos a `bs`/`usd` |
| `formatearMonto()` | monto confirmado con dos decimales y coma |
| `OcrCoordinateMapper` | píxeles de imagen ↔ visor `BoxFit.contain` |
| `AutomaticCommaFormatter` | desplazamiento opcional de decimales |
| `etiquetaMoneda()` / `etiquetaSelectorMoneda()` | etiquetas USD ($), EUR (€), VES (Bs.) y contexto |
| `mostrarCalendarioTasa()` | selector de fecha reutilizado por inicio y hoja de tasas |

## UI actual

- El inicio prioriza selector, monto y resultado dentro de un único panel.
- El contenido se centra verticalmente cuando cabe en la pantalla y conserva
  desplazamiento en alturas pequeñas. El cambio de dirección ocupa una fila
  propia debajo de las dos monedas; la divisa BCV/P2P recibe más ancho que VES.
- No hay cabecera: Calendario, Ajustes y Escanear son botones tonales dentro del
  contenido.
- Existe un solo acceso visible al escaneo OCR.
- Las monedas se muestran de forma explícita: `USD ($)`, `EUR (€)` y
  `VES (Bs.)`; el campo indica la moneda de entrada.
- Montos, resultados, tasas visibles, copias y widgets usan dos decimales. Los
  cálculos de la app conservan internamente la precisión recibida del proveedor.
- El teclado no redimensiona el `Scaffold`; monto y resultado conservan su
  geometría y el contenido secundario puede quedar detrás del teclado. Arrastrar
  o tocar un espacio vacío retira el foco y cierra el teclado.
- La tarjeta de tasa abre `RatesSheet`, que conserva fuente, fechas, estado de
  caché, actualización y variación.

## OCR

1. Cámara o galería produce una ruta local.
2. `OcrService` valida y decodifica la imagen.
3. ML Kit Latin reconoce localmente texto y geometría.
4. `OcrSelectionScreen` permite tocar/arrastrar, copiar y revisar candidatos.
5. Antes de volver se confirma monto, separadores y moneda.

`OcrException` distingue lectura, decodificación, reconocimiento y adaptación.
Los detalles técnicos incluyen código y mensaje de `PlatformException`; no se
muestran fuera del panel desplegable de diagnóstico.

La APK release debe conservar los constructores de implementaciones de
`ComponentRegistrar`; `android/app/proguard-rules.pro` contiene la regla R8.

## Widgets Android

- Widget 4×2: conversor rápido con cuatro presets configurables desde Ajustes,
  cambio USD/EUR y dirección moneda↔VES. Los valores por defecto son
  1/10/50/100; tocar el fondo abre la app y enfoca el monto para un valor
  arbitrario.
- Widget 2×2: conversión de una unidad en USD o EUR, elección global desde
  Ajustes.
- La UI es Kotlin/XML `RemoteViews`; Flutter publica un snapshot V3 con texto
  de dos decimales y tasas numéricas sin redondear para el cálculo nativo.
- Un contenedor transparente con tarjeta interior, radio del sistema en Android
  12+ y `clipToOutline` hace visibles las esquinas redondeadas en el launcher.
- WorkManager solicita actualización aproximada cada hora cuando detecta una
  instancia. Doze y el fabricante pueden retrasarla.
- El snapshot del launcher siempre representa la tasa oficial actual; visitar
  histórico o USDT no debe reemplazarlo.

## Comandos

```bash
make analyze
make test
make build-apk          # release ARM64
make build-apk-debug
make run
```

Al cambiar un contrato público, una regla transversal o un flujo nativo,
actualizar este documento y, si hay una decisión nueva, `decisiones.md`.
