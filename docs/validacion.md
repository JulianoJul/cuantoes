# Estado de validación

Actualizado: 28 de septiembre de 2026.

## Verificado

- `flutter analyze`: sin incidencias.
- Suite completa `flutter test`: 66 pruebas aprobadas.
- Inicio con viewport 360×640 e inset de teclado de 280 dp: el panel conserva
  su tamaño y no produce overflow.
- Samsung SM-A156M, Android 16/API 36, One UI Launcher:
  - UI principal en modo oscuro.
  - Gboard abierto sin desplazar ni deformar selector, monto o resultado.
  - Galería → PNG real → ML Kit → regiones seleccionables.
- APK release final:
  - ABI nativa única `arm64-v8a`.
  - manifiesto `debuggable=false`.
  - SHA-256: `26eb87ce27afd49272b5eb572ab548033894a751cd60be399d634a8e52bf2ec5`.
  - Esos mismos bytes se instalaron en el Samsung: el contenido queda centrado,
    el selector BCV/P2P conserva más ancho que VES y existe separación visible
    entre «Intercambiar» y «Monto».
  - Gboard abierto: tocar el área vacía cambió `mInputShown=true` a `false`.
  - Ajustes publicó `1/3/5/15`; el launcher actualizó los cuatro botones y tocar
    `15` mostró `15,00 USD → 12.855,09 Bs.` sin abrir la app.

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
- `home_widget` y `workmanager_android` aún aplican el plugin Kotlin clásico;
  Flutter avisa que versiones futuras exigirán su migración.

## Criterio para cerrar una prueba nativa

Un test Dart o un build exitoso no cierran OCR, cámara ni widgets. Registrar:

1. modelo de teléfono y versión Android;
2. variante exacta (`debug`/`release`) y hash del APK;
3. pasos y archivo usado;
4. captura o salida observable;
5. extracto de `adb logcat` cuando haya un fallo.
