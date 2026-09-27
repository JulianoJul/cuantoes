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

## Arquitectura

```
lib/
├── main.dart                        # CuantoesApp, MaterialApp, locale es
├── models/
│   └── tasa_bcv.dart                # TasaBcv (USD, EUR, USDT, fecha, origen, fechaEfectiva)
├── utils/
│   ├── feriados_ve.dart             # Feriados bancarios VE (fijos + Pascua)
│   └── numeros_ocr.dart             # Extracción y parseo de números desde OCR
├── services/
│   ├── bcv_provider.dart            # Contrato común de proveedores
│   ├── bcv_api_service.dart         # DolarAPI (proveedor principal)
│   ├── bcv_today_service.dart       # BCV Today (fallback 1)
│   ├── chitty_bcv_service.dart      # Chitty BCV (fallback 2 + USDT)
│   ├── bcv_cache_service.dart       # SharedPreferences
│   ├── ocr_service.dart              # Texto desde imagen (ML Kit)
│   └── tasa_repository.dart          # proveedores en cascada → cache
├── viewmodels/
│   └── conversor_viewmodel.dart     # ChangeNotifier, moneda, fechas, conversión, variación
└── screens/
    └── conversor_screen.dart        # UI: tabs USD/EUR/USDT, calendario, conversor
```

## Flujo de datos

### Tasa actual
```
Usuario → ConversorViewmodel.cargarTasa() → TasaRepository.obtenerTasa()
                                                 ├── cache con fechaEfectiva ≤ hoy VE y vigente? → retorna
                                                 └── refrescarTasa()
                                                      ├── DolarAPI → guarda cache
                                                      ├── BCV Today → guarda cache
                                                      ├── Chitty BCV → guarda cache
                                                      └── última cache válida → retorna
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
- `OcrService.reconocerTexto(ruta)` procesa la imagen con ML Kit (script Latin, on-device, sin conexión).
- `extraerNumeros(texto)` devuelve los tokens numéricos parseados, sin repetidos y en orden de aparición.
- `parsearNumero(token)` soporta `1.234,56`, `848,5458` y `10.50`; un separador único con 3 dígitos se interpreta como miles.
- La UI ofrece cámara o galería y un diálogo con los números detectados; el elegido llena la entrada del conversor.

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
flutter build apk        # build release Android
flutter build apk --debug # build debug
flutter test             # pruebas
```
