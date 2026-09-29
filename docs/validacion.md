# Estado de validación

Actualizado: 29 de septiembre de 2026.

## Verificado

- `dart format --output=none --set-exit-if-changed lib test`: 41 archivos
  revisados, sin cambios pendientes de formato.
- `flutter analyze`: sin incidencias.
- Suite completa `flutter test`: 80 pruebas aprobadas.
- Inicio con viewport 360×640 e inset de teclado de 280 dp: el panel conserva
  su tamaño y no produce overflow.
- Samsung SM-A156M, Android 16/API 36, One UI Launcher:
  - UI principal en modo oscuro.
  - Gboard abierto sin desplazar ni deformar selector, monto o resultado.
  - Galería → PNG real → ML Kit → regiones seleccionables.
- APK release ARM64 (flujo de tasa próxima):
  - ABI nativa única `arm64-v8a`.
  - APK compilada: `build/app/outputs/flutter-apk/app-release.apk` (34,1 MB).
  - SHA-256: `a3c8e8d19efa553eaf1da60947002921953a6e7a6fe679a2fac687f0560752e8`.
  - Instalada y abierta en Samsung SM-A156M, Android 16/API 36.
  - El build todavía imprime el aviso KGP para `home_widget` y
    `workmanager_android`: sus scripts incluyen aplicación condicional de KGP,
    detectada estáticamente por Flutter aunque `android.builtInKotlin=true` y
    el build release concluya correctamente. Los avisos de `System::load` vienen
    de Gradle/JVM, no del código de la app.

## Incidente OCR release resuelto

### Síntoma

La APK release mostraba «Falló el reconocimiento de texto en el dispositivo»;
debug reconocía la misma imagen.

### Causa

R8 conservaba los nombres de las clases que implementan
`com.google.firebase.components.ComponentRegistrar`, pero eliminaba sus
constructores públicos sin argumentos. `ComponentDiscovery` no podía crear:

- `CommonComponentRegistrar`
- `VisionCommonRegistrar`
- `TextRegistrar`

El registro contenía `NoSuchMethodException` y el canal de ML Kit terminaba en
`NullPointerException` antes de procesar la imagen.

### Corrección

`android/app/proguard-rules.pro` conserva únicamente esos constructores por
contrato de interfaz. No se desactivó R8 ni se añadieron modelos innecesarios.

## Pendientes reales

### Tasa próxima y calendario

- Probar manualmente en el teléfono la próxima tasa publicada, seleccionarla,
  reabrir el calendario y forzar actualización con y sin red. Los casos de
  proveedor secundario, falta de tasa actual, refresco y límites de fecha tienen
  pruebas automatizadas.
- Verificar en ejecución prolongada el refresco al reanudar y cada 30 minutos.

### UI y accesibilidad

- Probar modo claro manualmente.
- Probar landscape y tamaños de texto 130%/200%.
- Probar cantidades muy largas, pegado y edición de selección en el teléfono.

### OCR y cámara

- Cámara física: permiso denegado, cancelación y reapertura.
- Fotos JPEG con EXIF 90/180/270°, espejado, zoom y pan del visor.
- Primera ejecución de release totalmente offline.
- Foto de ticket/documento real y transferencia final del monto al conversor.

### Widgets

- Añadir y quitar ambos widgets en el launcher real.
- Estado vacío, redimensionado, varias instancias y clic de apertura.
- Actualización con proceso cerrado, reinicio, offline, retorno de red y Doze.
- Confirmar que histórico y USDT no alteran el snapshot oficial.

### Distribución

- Release todavía usa la firma debug. Configurar una clave de producción antes
  de publicar.
- Flutter mantiene un aviso estático de KGP para `home_widget` y
  `workmanager_android`, incluso en este build con Kotlin integrado activo.
  Desaparecerá cuando sus scripts upstream dejen de declarar la aplicación
  condicional del plugin KGP.

## Criterio para cerrar una prueba nativa

Un test Dart o un build exitoso no cierran OCR, cámara ni widgets. Registrar:

1. modelo de teléfono y versión Android;
2. variante exacta (`debug`/`release`) y hash del APK;
3. pasos y archivo usado;
4. captura o salida observable;
5. extracto de `adb logcat` cuando haya un fallo.
