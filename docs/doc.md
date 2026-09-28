# Cuantoes — Documentación

## Mapa de documentación

- Este archivo: arquitectura, flujo de datos y proveedores actuales.
- `funciones.md`: catálogo de modelos, servicios, ViewModel y utilidades.
- `decisiones.md`: decisiones de arquitectura (ADR) y contexto histórico.
- `google-stitch-prompt.txt`: prompt listo para generar un rediseño UI/UX.

## Stack

| Capa | Tecnología |
|------|-----------|
| Framework | Flutter (Dart 3.12+) |
| Estado | Provider + ChangeNotifier |
| HTTP | http (APIs JSON) |
| Cache | shared_preferences |
| Formato | intl |
| Localización | flutter_localizations (es) |
| OCR | google_mlkit_text_recognition (on-device, offline) + image_picker |
| Widgets Android | home_widget (puente de datos) + Workmanager; UI nativa con RemoteViews |

## Arquitectura

```
lib/
├── main.dart                        # CuantoesApp, MaterialApp, locale es
├── models/
│   ├── tasa_bcv.dart                # Tasa oficial USD/EUR
│   ├── cotizacion_usdt.dart         # Referencia P2P, independiente del BCV
│   ├── resultado_tasa.dart          # Modo de obtención y frescura
│   ├── documento_ocr.dart           # Texto y regiones con geometría
│   └── widget_snapshot.dart         # Contrato versionado con RemoteViews
├── utils/
│   ├── feriados_ve.dart             # Feriados bancarios VE (fijos + Pascua)
│   └── numeros_ocr.dart             # Extracción y parseo de números desde OCR
├── services/
│   ├── bcv_provider.dart            # Contrato común de proveedores
│   ├── bcv_api_service.dart         # DolarAPI (proveedor principal)
│   ├── bcv_today_service.dart       # BCV Today (fallback 1)
│   ├── chitty_bcv_service.dart      # Chitty BCV (fallback 2 + USDT)
│   ├── bcv_cache_service.dart       # SharedPreferences
│   ├── ocr_service.dart              # Texto y geometría desde ML Kit
│   ├── tasa_repository.dart          # proveedores en cascada → cache
│   ├── home_widget_service.dart      # Snapshot y actualización de widgets
│   └── widget_background_refresh.dart # Tarea periódica WorkManager
├── viewmodels/
│   └── conversor_viewmodel.dart     # ChangeNotifier, moneda, fechas, conversión, variación
└── screens/
    ├── conversor_screen.dart        # UI adaptable, tasas, calendario y conversor
    ├── camera_capture_screen.dart   # Captura con lifecycle
    └── ocr_selection_screen.dart   # Foto, overlay, selección y transferencia

android/app/src/main/
├── kotlin/.../BcvWidgetProvider.kt # AppWidgetProvider nativo grande/compacto
└── res/layout + res/xml            # RemoteViews y configuración Android
```

## Flujo de datos

### Tasa actual
```
Usuario → ConversorViewmodel.cargarTasa() → TasaRepository.obtenerTasaConEstado()
                                                 ├── caché válida para el día efectivo → retorna con metadatos
                                                 └── refrescarTasaConEstado()
                                                      ├── DolarAPI → BCV Today → Chitty BCV
                                                      └── última tasa aplicable en caché

Tasa actual → HomeWidgetService → snapshot versionado → AppWidgetProvider nativo
```

La cache consultada como tasa actual nunca devuelve una entrada con
`fechaEfectiva` posterior a hoy en Venezuela. Una entrada futura puede permanecer
en cache para informar la siguiente tasa disponible.

### Tasa histórica
```
Usuario → ConversorViewmodel.seleccionarFecha()
             ├── TasaRepository.obtenerTasaHistorica()
             │       ├── cache exacta por fecha efectiva? → retorna
              │       ├── proveedores con histórico → guarda cache
              │       └── se devuelve la mayor fecha efectiva ≤ solicitada entre proveedor y cache
             └── _fechaSeleccionada conserva la fecha elegida
```

El histórico de la API puede estar incompleto (p. ej. USD sin datos de algunos
días), por lo que la caché de tiempo real se usa como fuente complementaria y
gana la fecha efectiva más cercana a la solicitada.

El calendario permite seleccionar fines de semana y feriados. La tasa aplicada
es la de mayor `fechaEfectiva ≤` la fecha solicitada; la tarjeta muestra esa
fecha como `Tasa aplicada` sin cambiar visualmente la fecha seleccionada.

Las fechas futuras solo se habilitan hasta la fecha efectiva de la próxima tasa
ya publicada (hoy si aún no existe), de modo que "mañana" no puede elegirse
antes de que aparezca su tasa.

### Variación porcentual
- `ConversorViewmodel._calcularVariacion()`: compara la tasa actual o histórica con la tasa de la fecha efectiva inmediatamente anterior
- `TasaRepository.obtenerTasaAnterior()` resuelve esa tasa previa desde cache o proveedores
- Visible para USD y EUR con o sin fecha seleccionada; no para USDT
- Se muestra en la UI como "▲ +0.61%" / "▼ -0.20%" junto a la tasa correspondiente

### Escaneo de precios (OCR)
- `OcrService.reconocerDocumento(ruta)` procesa la foto con ML Kit Latin on-device y conserva bloques, líneas, polígonos y dimensiones.
- `OcrSelectionScreen` dibuja las regiones sobre la foto, permite selección por toque/arrastre, selección accesible y copia.
- `extraerNumeros(texto)` conserva apariciones repetidas y posiciones; `parsearNumero(token)` no fusiona números separados por espacios y señala separadores ambiguos.
- Antes de transferir, se revisan el monto, la interpretación de miles/decimales y la moneda VES/USD/EUR/USDT. El sentido de conversión se ajusta con el monto.
- `ImagePicker.retrieveLostData()` recupera una imagen si Android destruye la Activity durante la selección.

### Widgets Android
- `BcvWidgetProvider` y `BcvCompactWidgetProvider` son widgets nativos `AppWidgetProvider` con layouts XML `RemoteViews`; no usan Flutter en el launcher.
- `HomeWidgetService` comparte USD/EUR, fecha efectiva, fuente y estado de validación en un snapshot versionado.
- El widget principal es 4×2. El compacto 2×2 muestra USD o EUR, configurable globalmente desde el Drawer.
- WorkManager intenta refrescar cada 60 minutos cuando detecta una instancia instalada y hay red; Android puede aplazarlo por Doze o ahorro de batería.
- Pruebas en launcher real, reinicio/Doze, cámara física y flujo OCR de extremo a extremo siguen pendientes.

### Fechas y fuentes
- DolarAPI y los históricos de los proveedores solo combinan USD y EUR de una misma `fechaEfectiva` común.
- BCV Today usa el campo `effective_date` de sus snapshots.
- Chitty BCV infiere la fecha hábil anterior desde `updated_at` cuando su dataset no publica una fecha efectiva explícita.

## Proveedores y fechas
- `DolarApiService` consulta USD/EUR actuales y sus históricos oficiales.
- `BcvTodayService` consulta `rate.json` y snapshots diarios estáticos.
- `ChittyBcvService` funciona como fallback de la tasa actual y proporciona
  USDT mediante su histórico P2P; no se usa para históricos oficiales USD/EUR.
- Todos los proveedores normalizan la respuesta al modelo `TasaBcv` antes de
  entrar al repositorio.

## Comandos

```bash
flutter analyze          # análisis estático
  flutter build apk --release --target-platform android-arm64 # entrega ARM64
flutter build apk --debug # build debug
flutter test             # pruebas
```
