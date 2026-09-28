# Cuantoes — Plan V2: conversor despejado, OCR operativo y widget Android fiable

- **Autor:** Astra.
- **Fecha:** 27 de septiembre de 2026.
- **Estado:** plan de diseño y reparación; pendiente de implementación.
- **Antecedente:** [auditoria-y-plan-luna.md](auditoria-y-plan-luna.md).
- **Base:** checkout actual con cambios sin commit y las dos capturas compartidas por el usuario.

## 1. Objetivo y criterio principal

**Abrir Cuantoes, tocar el monto y escribir cómodamente debe ser la experiencia principal.** Monto, moneda y resultado tienen prioridad sobre la tabla de tasas, el calendario, la marca y los accesos secundarios.

Esta iteración debe resolver tres problemas reportados:

1. La pantalla de inicio está sobrecargada y desplaza demasiado abajo la entrada numérica.
2. El OCR falla tanto al tomar una foto como al elegir una imagen del teléfono, con el mensaje «No se pudo reconocer esta imagen…».
3. El widget Android 4×2 muestra un error en el launcher.

Este documento define la nueva UI y el trabajo de reparación. Se conserva el plan anterior como antecedente; **este V2 prevalece en la organización de la pantalla principal y en las prioridades de OCR/widgets**.

### Condiciones que debe conservar la implementación

- Flutter/Material 3 + Provider y un solo estado de conversión.
- DolarAPI → BCV Today → Chitty BCV → caché; USD/EUR oficiales separados de USDT P2P.
- Fecha efectiva, fecha solicitada y validación de red con significados distintos.
- OCR local, selección de texto sobre la foto, copia y transferencia explícita de monto/moneda/dirección.
- Widgets del launcher Android con `AppWidgetProvider` y `RemoteViews` nativas.
- Compatibilidad con las preferencias y tasas guardadas existentes.

## 2. Evidencia y diagnóstico actual

### 2.1 Qué se sabe

Las capturas muestran el inicio y el Drawer; los errores de OCR y widget se conocen por el relato del usuario. No se dispone de su excepción original, logcat, modelo de teléfono, versión de Android ni launcher.

Se revisaron los archivos actuales de pantalla, ViewModel, OCR, captura, snapshot, WorkManager, Kotlin/XML y pruebas, además de los adaptadores del plugin ML Kit instalado y la documentación oficial de RemoteViews.

El plan anterior registra análisis limpio, 55 pruebas aprobadas y build ARM64. Es **evidencia de la entrega previa**, no una reproducción de estos fallos. Sus pruebas OCR construyen objetos `RecognizedText` en Dart: no recorren archivo real → plugin → motor nativo. Las pruebas del snapshot tampoco inflan RemoteViews en un host Android. No se ejecutaron nuevos builds ni ensayos físicos para redactar este plan.

### 2.2 Hallazgos que guían esta iteración

Las líneas son orientativas y corresponden al checkout revisado.

| ID | Hallazgo y evidencia | Consecuencia / prioridad |
|---|---|---|
| UI-01 | `conversor_screen.dart:112–152`: AppBar, cabecera repetida, tabla USD/EUR, chips, calendario y aviso de próxima tasa preceden al campo. En la captura el monto empieza después de la mitad vertical. | Reordenar la jerarquía, no limitarse a reducir espacios. **P1**. |
| UI-02 | `_buildDrawer`, líneas 162–230: cabecera grande y tres ajustes ocupan una superficie extensa; también repite la fuente de datos. | Sustituir por una pantalla compacta de Ajustes. **P2**. |
| UI-03 | `_buildEntrada`, líneas 388–400: el botón OCR desaparece cuando hay texto y se reemplaza por limpiar. | Escanear debe seguir disponible con un monto ya escrito. **P1**. |
| UI-04 | `_buildAtajos`, líneas 774–784, llama a `setEntrada`; este método (`conversor_viewmodel.dart:345–350`) no sincroniza `entradaController`. | Un atajo puede cambiar el cálculo sin cambiar lo que muestra el campo. Retirarlos del inicio y unificar inserción programática. **P1**. |
| UI-05 | `test/conversor_screen_test.dart:77–92` solo verifica existencia de `TextField` y ausencia de excepciones con insets. | Un campo fuera del viewport puede pasar la prueba. Medir visibilidad y capacidad real de escribir/copiar. **P1**. |
| OCR-01 | `ocr_selection_screen.dart:38–59,485–505`: todo error recibe el mismo mensaje; no se conserva stack trace ni etapa. | Aún no hay causa raíz demostrada del fallo reportado. Instrumentar primero. **P1**. |
| OCR-02 | `ocr_service.dart:12–30`: lectura y decodificación Flutter completas antes de ML Kit; `getNextFrame()` queda fuera del `try`; `close()` se espera en `finally`. | Un error de decodificación o de cierre puede parecer fallo de reconocimiento; revisar recursos y conservar la excepción primaria. **P1**. |
| OCR-03 | Flutter mide una imagen decodificada y ML Kit abre por su cuenta el archivo original. | Falta un contrato explícito de orientación/dimensiones comunes. Puede desalinear el overlay; no demuestra por sí solo el error universal. **P1**. |
| W-01 | `android/app/src/main/res/layout/widget_bcv.xml:50–54` contiene un `<View>` usado como divisor. | **Defecto concreto:** `android.view.View` no forma parte de las clases admitidas por RemoteViews. Hipótesis principal de la inflación fallida del 4×2; confirmar con el host/logcat. **P1**. |
| W-02 | El XML compacto utiliza `LinearLayout`/`TextView` y no ese divisor. | Comparar ambos widgets ayuda a aislar el problema específico del 4×2. No se asume que el compacto esté validado. |
| W-03 | `home_widget_service.dart:16–49`: varias claves se escriben por separado, la versión constante se escribe al final y los fallos se silencian. | La versión ya existente no evita un snapshot mezclado en una actualización interrumpida. El worker puede informar éxito sin haber publicado. **P2**. |
| W-04 | `widget_background_refresh.dart:15–40`: la programación se comprueba al abrir/reanudar la app; los providers no coordinan altas/bajas del trabajo. | Añadir el primer widget con la app cerrada puede dejarlo sin trabajo periódico hasta reabrirla. **P2**. |

**Distinción importante:** W-01 es una incompatibilidad verificable del XML. Su vínculo exacto con el error del teléfono requiere reproducción. En OCR todavía no hay una hipótesis única suficientemente respaldada.

## 3. Nueva experiencia: el conversor primero

### 3.1 Navegación elegida

- **Inicio = conversor.** Una cabecera pequeña y un único bloque principal de entrada/resultado.
- **Tasas y fecha = hoja modal desplazable**, abierta desde el resumen de la tasa aplicada.
- **Ajustes = pantalla propia**, abierta con el engranaje de la cabecera.
- **Escanear = ruta propia**, accesible desde un botón con etiqueta en el inicio y un acceso compacto al escribir.

No hace falta una barra inferior de pestañas para estas tareas. La información secundaria se consulta a demanda y el monto permanece en el mismo estado al volver.

### 3.2 Boceto del inicio en reposo

Datos ilustrativos, nunca constantes de producción:

```text
┌──────────────────────────────────────┐
│ Cuantoes                         ⚙   │
│                                      │
│ ┌──────────────────────────────────┐ │
│ │ [ USD ▾ ]       ⇄          VES   │ │
│ │ Monto                            │ │
│ │ 10                            ×  │ │
│ │                                  │ │
│ │ Resultado en bolívares      Copiar│ │
│ │ 8.556,63                         │ │
│ └──────────────────────────────────┘ │
│                                      │
│ [ Escanear texto ]                    │
│                                      │
│ BCV · 1 USD = Bs. 855,6625           › │
│ Fecha valor 25/09 · Tasas y fecha      │
│                                      │
│       espacio libre para escribir    │
└──────────────────────────────────────┘
```

Decisiones concretas:

1. Eliminar la cabecera decorativa «Tasa BCV» y su icono grande. «Cuantoes» aparece una sola vez.
2. Mover la tabla USD/EUR, variaciones, fuente detallada, próxima publicación y calendario a la hoja de tasas.
3. Integrar el selector de divisa y el intercambio en la cabecera del bloque de conversión. Selector con USD, EUR y USDT; P2P claramente identificado al elegir USDT.
4. VES es el lado fijo del par; el selector de divisa cambia de lado visual al invertir. No ofrecer pares arbitrarios que el motor no soporta.
5. Mantener un solo campo editable grande. Resultado claramente rotulado y de solo lectura, con copia al lado.
6. Dejar limpiar dentro del campo y escanear fuera. Las dos acciones no compiten por el mismo espacio.
7. Retirar los cuatro atajos monetarios del inicio predeterminado: no justifican dos filas alrededor de la tarea principal.
8. El refresco manual vive en «Tasas y fecha»; un fallo añade un acceso «Reintentar» contextual. El inicio no necesita un botón de actualización grande permanente.
9. Conservar un resumen de la tasa realmente aplicada. En la captura, mostrar solo `855,66` puede hacer que `10 → 8.556,63` parezca inconsistente: usar hasta cuatro decimales en el resumen y precisión completa en el detalle; calcular siempre con el valor original.

### 3.3 Modo de escritura: entrada y resultado junto al teclado

```text
┌──────────────────────────────────────┐
│ Cuantoes                  Escanear ⚙ │
│ [ USD ▾ ]            ⇄         VES  │
│ Monto: 10                         × │
│ Resultado: Bs. 8.556,63       Copiar │
│ BCV · 25/09 · Tasas y fecha        › │
├──────────────────────────────────────┤
│          teclado numérico            │
└──────────────────────────────────────┘
```

- Un toque en el campo abre el teclado numérico del sistema. No forzarlo al arrancar: la tasa también puede consultarse sin editar.
- Al abrirse el teclado, reducir padding decorativo y trasladar el acceso «Escanear texto» a una acción compacta. El monto y el resultado conservan su identidad, controlador y foco; no remontar dos formularios distintos.
- Usar `FocusNode`, espacio disponible de `LayoutBuilder` y `viewInsets` para adaptar la composición. `adjustResize` ya existe en el manifiesto: verificar su comportamiento real con edge-to-edge.
- Hacer que el campo activo y el resultado estén en el área visible. Evitar `Spacer`/alturas a pantalla completa dentro de la composición principal. Permitir scroll residual en alturas extremas y texto grande.
- Cambiar divisa, limpiar o copiar no debe cerrar el teclado involuntariamente. Las consultas asíncronas no deben mover el cursor ni reconstruir el campo con otra clave.
- Conservar las preferencias de coma automática. Un monto programático —OCR, pegado normalizado o intercambio— no debe volver a interpretarse como centavos al continuar editándolo.
- Admitir entrada vacía e incompleta sin resultado viejo; cero sigue siendo un monto válido. La ausencia de tasa deshabilita el resultado, no la escritura.
- Volver de tasas/ajustes restaura el monto; volver de OCR aplica la transferencia confirmada y restaura el foco si el usuario estaba escribiendo. Cancelar conserva la entrada anterior.

**Objetivo medible:** en 360×640 dp, escala de texto 100% e inset inferior de 280 dp, campo y resultado/copiar deben ser visibles simultáneamente después de enfocar, sin desplazamiento manual. En 320 dp, landscape o texto 200%, priorizar accesibilidad mediante scroll, sin recortar el monto ni desactivar escalado.

### 3.4 Hoja «Tasas y fecha»

Contenido, en este orden:

1. Contexto: **Actual / Consultar fecha**. En histórico, fecha solicitada y aplicada por separado; acción «Volver a actual».
2. Tasas USD y EUR, con la precisión del dato y fuente real.
3. Fecha efectiva y última validación satisfactoria. Una lectura de caché no se presenta como sincronización de red.
4. Próxima tasa cuando realmente existe; permitir usar su fecha de forma explícita, mostrando «Próxima · DD/MM» en el conversor.
5. Variación disponible por moneda, sin completar valores que no hayan sido calculados.
6. USDT en sección separada «Referencia P2P», con su fecha de promedio, proveedor y antigüedad propios. No rotularlo BCV ni en vivo.
7. Actualización de la fuente correspondiente, con estado de carga y reintento.

La hoja reutiliza el estado/repositorio existentes. Abrirla o reconstruirla no dispara una nueva descarga por defecto. Cerrar la hoja no abandona automáticamente una fecha seleccionada.

### 3.5 Estados que siguen visibles en el inicio

La simplificación no debe esconder el contexto que modifica el cálculo:

| Estado | Presentación compacta |
|---|---|
| Actual disponible | Resumen de tasa y fecha efectiva; acceso al detalle. |
| Histórico seleccionado | «Histórico · solicitada DD/MM · aplicada DD/MM» y volver a actual. Permitir dos líneas si hace falta. |
| Próxima tasa seleccionada | «Próxima · DD/MM», sin confundirla con la tasa de hoy. |
| Caché normal | «Tasa guardada · fecha valor DD/MM»; validación detallada en la hoja. |
| Falló actualizar | Una sola franja contextual «No se pudo actualizar · tasa guardada» y reintento. No afirmar «sin conexión» si solo se sabe que falló una fuente. |
| Dato antiguo | Advertencia junto al contexto, incluso con teclado abierto; no esconderla dentro de la hoja. |
| Sin tasa de la moneda | Mantener campo editable; mostrar «Sin tasa disponible» en vez de cero o resultado anterior. |
| USDT | Etiqueta P2P y estado de su propia cotización; BCV continúa utilizable. |

### 3.6 Ajustes y dirección visual

- Sustituir el Drawer por una pantalla desplazable con AppBar «Ajustes» y volver.
- Filas compactas para tema, coma automática —con ejemplo breve— y divisa del widget compacto.
- Etiquetar la preferencia actual de widget como **global**: «Aplicar a todos los widgets compactos». La configuración por instancia no es necesaria para arreglar el 4×2.
- Los datos del proveedor pertenecen a tasas, no al pie de ajustes.
- Conservar las preferencias previas al mover los controles.
- Fondo claro suave y superficie blanca; oscuro azul profundo según la paleta actual. Azul para selección/acción y color de advertencia solo cuando procede.
- Márgenes laterales orientativos de 16 dp, radios de 16–20 dp y separaciones de 8–16 dp. Reducir marcos y divisores repetidos; un solo contenedor principal.
- Monto de 36–44 sp y resultado de 28–36 sp como punto de partida, adaptados a altura y longitud. No truncar números con `…`; facilitar desplazamiento/selección para cantidades largas.
- Controles táctiles de al menos 48 dp. El aspecto compacto no reduce su superficie táctil.
- Corregir contraste de barra de estado/navegación por tema; en las capturas los iconos blancos sobre fondo muy claro se leen mal. Revisar también teclado, hoja y cámara al volver.

## 4. OCR: localizar el fallo antes de cambiar la integración

### 4.1 Hipótesis y cómo distinguirlas

Que falle desde cámara y galería apunta a una etapa compartida, pero no demuestra que ML Kit sea la causa.

| Etapa | Qué comprobar | Evidencia que permite decidir |
|---|---|---|
| Lectura | Archivo existente, permisos de lectura, bytes no vacíos; diferenciar ruta local de URI. | `FileSystemException`, tamaño y esquema del origen. |
| Decodificación Flutter | `instantiateImageCodec` / `getNextFrame`, tipo real de archivo, resolución y memoria. | Excepción/stack de codec; comparar PNG/JPEG pequeños contra la foto completa. |
| Plugin/motor | Registro de plugin, canal, inicialización Latin y proceso nativo. | `MissingPluginException` o `PlatformException` con `code`, `message`, `details`; logcat de registro/ML Kit. |
| Respuesta del plugin | Conversión `RecognizedText.fromJson` antes de llegar al adaptador de la app. | Stack de deserialización; payload reducido reproducible, incluyendo cajas nulas y tipos numéricos. |
| Adaptador propio | `documentoDesdeResultado`, parsing contextual, puntos y regiones. | Reconocimiento nativo satisfactorio seguido de excepción Dart en esta etapa. |
| Liberación | `recognizer.close()` y disposición de recursos. | Error de cierre después de un resultado correcto; no debe reemplazar el resultado ni la excepción primaria. |

La versión local `google_mlkit_text_recognition 0.17.1` declara `com.google.mlkit:text-recognition:16.0.1`, modelo Latin empaquetado. Los otros scripts son `compileOnly`; las reglas actuales `-dontwarn` silencian avisos sobre ellos. **Eso no prueba un fallo R8 ni justifica agregar todos los modelos o desactivar optimizaciones a ciegas.** Comparar debug/release con el mismo archivo y actuar según la excepción.

El adaptador Android del plugin permite `rect = null`, mientras el constructor Dart `RectJson.fromJson` recibe un mapa no nulo. Es una rama concreta que debe cubrirse si el stack apunta a deserialización, no una causa ya comprobada del reporte.

### 4.2 Primer bloque de implementación: diagnóstico reproducible

1. Reproducir con una captura PNG pequeña que contenga «Bs. 185,00 / USD 5,00», una foto JPEG desde galería y otra tomada por la cámara de la app.
2. Registrar etapa, duración, dimensiones, tamaño y tipo de excepción con stack. Conservar un ID de operación para relacionar los eventos Dart/nativos.
3. Capturar el error con `(error, stackTrace)` en el límite del flujo. La UI debe recibir un error tipado con etapa y acción recuperable; los detalles técnicos se consultan a demanda, no como párrafo en el inicio.
4. Probar primero el reconocimiento nativo de ese archivo conocido, luego adaptación y selección. Separar el motor de la decodificación añadida para medir la imagen permite saber si esta última es el bloqueo.
5. Comparar la misma fixture en debug y release ARM64. Si solo falla release, inspeccionar registro, clases/modelo empaquetados y reglas del plugin con evidencia concreta.
6. Conservar el fallo primario aunque `close()` también falle. Garantizar cierre de codec/imagen si falla `getNextFrame()` y que abandonar la ruta no produzca callbacks sobre un estado destruido.

No registrar fotos, texto reconocido completo ni rutas personales en los logs de diagnóstico. Bastan etapa, formato, tamaños y excepción; usar fixtures sintéticas para capturar payloads.

**Salida requerida:** excepción original y etapa identificadas, fixture que reproduce el problema y corrección mínima demostrada. Si depende de un defecto del plugin, fijar una versión corregida o un parche mantenido en el repositorio; no editar `.pub-cache` como solución distribuible.

### 4.3 Contrato de imagen común para motor y visor

Después de identificar el fallo, estabilizar la entrada compartida de cámara/galería:

- Crear un adaptador pequeño `ImageInputService` que reciba el archivo elegido/capturado y entregue una imagen de sesión: ruta local legible, ancho/alto, orientación aplicada y propiedad del temporal.
- Normalizar orientación EXIF una sola vez, incluidos los casos espejados. Si se exporta una copia JPEG/PNG, sus píxeles y orientación deben corresponder exactamente a la imagen enviada a ML Kit y mostrada en el visor.
- Acotar resolución y memoria antes de una decodificación completa de fotos enormes; conservar suficiente tamaño de letra. Documentar el límite elegido con fixtures y medición, evitando varias copias RGBA a resolución original.
- Usar el mismo espacio de coordenadas después del redimensionado. No aplicar la rotación o la escala por segunda vez al overlay.
- Mantener el temporal mientras el visor/reintento lo necesite y limpiar solo archivos creados por la app; nunca borrar el original de galería.
- Recuperar `retrieveLostData()` y conducirlo por el mismo adaptador. Los fallos de recuperación deben distinguirse del caso «no había selección pendiente».
- Mantener reconocimiento local/offline. Un fallo técnico no debe convertirse en un envío a un servicio remoto.

### 4.4 UI del OCR y regreso al conversor

- Pantalla independiente con la foto como elemento principal, estado de proceso y acción volver/cancelar.
- Estados distintos: preparando imagen, reconociendo, texto listo, imagen sin texto, archivo ilegible, formato no admitido y error del motor.
- Reintentar solo donde tenga sentido. Ofrecer **«Elegir otra imagen» como acción real**; hoy el mensaje la menciona, pero la pantalla solo muestra «Reintentar».
- Conservar copia de texto arbitrario: no condicionar toda la selección a que existan importes.
- Barra inferior compacta «Copiar» / «Usar monto»; panel accesible desplegable con selección de líneas que no compita con los gestos de `SelectableText`.
- Validar selección con zoom/pan y rotación; la tolerancia de toque debe mantenerse en píxeles lógicos, contemplando tanto `BoxFit` como zoom. No aplicar dos veces la inversa de la transformación del hijo de `InteractiveViewer`.
- Dar al painter una selección inmutable o una revisión para invalidar repintado explícitamente: el `Set` mutable compartido no es una señal fiable de cambio por identidad.
- Hoja de revisión monetaria desplazable y adaptada al teclado: un candidato explícito, moneda de origen y edición. Con varios candidatos, conservar ID/offset/región, no localizar solo por texto cuando hay montos repetidos.
- Detectar ambigüedad sobre el texto editado actual, no solo sobre el candidato inicial. `1,234` debe permitir elegir miles o decimales sin forzar silenciosamente una interpretación.
- Transferir con `aplicarMontoEscaneado` o su sucesor común: monto/controller/cursor, moneda, dirección y cálculo cambian juntos. Cancelar no modifica el conversor.

## 5. Widget 4×2: reparar la inflación y luego la actualización

### 5.1 Primera corrección candidata: layout válido para RemoteViews

`widget_bcv.xml` contiene un `<View>` entre las columnas. RemoteViews no acepta todos los elementos que Android puede compilar en un XML normal. La documentación admite `LinearLayout`, `FrameLayout`, `TextView`, `ImageView`, etc., pero no el `View` genérico utilizado.

Plan de reparación:

1. Capturar logcat de app **y launcher** al añadir el 4×2; buscar `InflateException`, `RemoteViews`, `AppWidgetHostView`, clase no permitida y errores del provider. Filtrar solo por PID de la app puede perder el fallo del host.
2. Añadir una prueba Android que llame a `RemoteViews.apply()` con el layout de producción y sus acciones, usando un contenedor host. Debe reproducir la incompatibilidad antes del cambio.
3. Eliminar el divisor o representarlo con una clase admitida, por ejemplo `ImageView` con fondo y ancho de 1 dp. No reemplazarlo por `Space`, un `View` propio, `ConstraintLayout` o un widget Material no admitido.
4. Verificar toda la jerarquía y los recursos de preview/initialLayout. En este caso ambos apuntan al mismo layout problemático.
5. Probar añadir un widget vacío, actualizar uno existente y usar datos reales. Debe poder inflarse **sin red y sin snapshot**.

Compilar, declarar el receiver o encontrarlo con AAPT no valida que el launcher pueda inflar el layout. El test nativo complementa, pero tampoco sustituye, el ensayo en el launcher del usuario.

### 5.2 Diseño del widget corregido

```text
┌──────────────────────────────────────┐
│ Cuantoes · BCV                        │
│ USD                Bs. 855,6625       │
│ EUR                Bs. 972,6487       │
│ Fecha valor 25/09 · DolarAPI           │
│ Validada 27/09 09:00                  │
└──────────────────────────────────────┘
```

- Preferir dos filas simples frente a columnas estrechas con valores monetarios truncados.
- Mantener tasas legibles y fecha efectiva visible. Ante poco espacio, reducir metadatos secundarios antes que recortar dígitos con `…`.
- Un estado breve diferencia sin datos, guardada, antigua y error de actualización. El error de layout del launcher nunca debe confundirse con ausencia de cotizaciones.
- Si no hay datos: «Abre Cuantoes para cargar tasas», con clic funcional.
- Recursos claros/oscuros nativos y contraste adecuado; no depender de un color fijo oscuro para ambos temas.
- Responder a `onAppWidgetOptionsChanged` y dimensionar según espacio real. Los 4×2 son una sugerencia de celdas; cada launcher asigna dp distintos.
- Revisar `minHeight=110dp`, `minResizeHeight=90dp` y padding actual: ajustar mínimos y variante pequeña según la altura real que necesita el contenido.
- Mantener identidad de los providers/componentes existentes para que actualizar la app no obligue a perder los widgets instalados.

### 5.3 Coherencia del snapshot y errores observables

Atender después de demostrar que el layout funciona:

1. Migrar las claves separadas a un **único JSON versionado** que contenga toda la cotización y sus metadatos. Escribir versión, valores y fechas como una unidad evita medias publicaciones.
2. Conservar lectura de las claves V1 como migración. La versión de esquema no es el ID de cada actualización: la constante `1` escrita al final no funciona como commit transaccional.
3. Guardar fecha efectiva civil, timestamps UTC completos y modo de obtención, además de los valores. El launcher debe poder mostrar antigüedad sin depender únicamente de una frase «Actualizada» guardada horas antes.
4. Verificar el resultado de persistencia y registrar fallos de publicación con contexto. No informar éxito del worker cuando publicar falló silenciosamente.
5. Coordinar foreground/background para impedir que un trabajo más antiguo sobrescriba un resultado nuevo; si la comparación se hace en nativo, comparar y escribir bajo el mismo control de concurrencia. Dos secuencias de leer/comparar/escribir en isolates no son atómicas.
6. Mantener el último snapshot íntegro si hay error de red o escritura. No borrar tasas útiles ni llenarlas con cero.
7. Publicar solo contexto actual oficial. Seleccionar histórico o próxima tasa en la app no debe sustituir la cotización actual del launcher.

### 5.4 Ciclo de vida y trabajo de fondo

- Coordinación explícita al añadir la primera instancia y quitar la última, contando ambos providers. Eliminar todos los 4×2 no cancela el trabajo si queda un compacto.
- Inicializar/persistir el callback headless correctamente y cubrir el caso de widget añadido antes de la primera apertura: vacío comprensible y programación efectiva al completar la inicialización.
- Si la app ya se inicializó antes, añadir un widget con su proceso cerrado debe poder activar la programación sin obligar a reabrir la pantalla.
- Reutilizar un trabajo periódico único con backoff y presupuesto de consulta. El receiver realiza tareas breves de render/encolado; no hace HTTP largo.
- Recargar preferencias cuando sea necesario entre motores/isolate para no publicar una copia local obsoleta de la caché.
- Redibujar desde el último snapshot aunque no haya red. Separar esta operación local del trabajo de red con constraint de conectividad.
- Verificar cierre normal, proceso eliminado, reinicio y Doze. **Forzar detención** desde ajustes de Android tiene restricciones distintas; no prometer que WorkManager las evade.
- Mantener periodo aproximado de 60 minutos y mensajes con fechas reales. Esta reparación no necesita alarmas exactas.

## 6. Organización del código para implementar el plan

Extraer responsabilidades durante los cambios, manteniendo las utilidades y reglas actuales. Rutas propuestas, no archivos ya creados por este documento:

| Ruta / área | Responsabilidad |
|---|---|
| `lib/screens/conversor_screen.dart` | Composición del inicio, foco y navegación. |
| `lib/widgets/conversion_panel.dart` | Campo, monedas, intercambio, resultado y copia, reutilizados en modo reposo/escritura. |
| `lib/widgets/rate_context_summary.dart` | Tasa aplicada y estados actual/histórico/P2P/error. |
| `lib/screens/rates_sheet.dart` | Detalle de tasas, fuente, calendario y refresco. |
| `lib/screens/settings_screen.dart` | Preferencias existentes y configuración compacta global. |
| `lib/theme/app_theme.dart` | Tokens claro/oscuro, tipografía y estilos de sistema. |
| `lib/services/image_input_service.dart` | Imagen de sesión, orientación, dimensiones y temporales. |
| `lib/services/ocr_service.dart` | Adaptador ML Kit, etapas diagnósticas y cierre de recursos. |
| `lib/screens/ocr_selection_screen.dart` | Visor y acciones; extraer overlay/estado de selección cuando simplifique esta pantalla. |
| `lib/viewmodels/conversor_viewmodel.dart` | Inserción coordinada y conversión independiente del layout. |
| `lib/services/home_widget_service.dart`, `widget_background_refresh.dart`, `models/widget_snapshot.dart` | Publicación verificable y coherencia con trabajo headless. |
| `android/app/src/main/kotlin/ve/cuantoes/cuantoes/` y `res/` | Render nativo, tamaños, lifecycle y lectura compatible del snapshot. |
| `integration_test/` y `android/app/src/androidTest/` | Ensayos del motor OCR y aplicación real de RemoteViews. |

### Contratos de interacción a corregir al extraer

- Separar «texto tecleado» de «insertar monto ya interpretado». La segunda acción sincroniza estado, `TextEditingController`, cursor y flag de coma automática.
- Cambiar moneda debe recalcular inmediatamente con los datos disponibles; la variación histórica es secundaria y no debe retener la interacción.
- Aplicar resultados asíncronos y metadatos después de validar la generación vigente. Actualmente `_resultadoTasa` se asigna antes de esa guarda en `cargarTasa`.
- Una respuesta tardía no puede reemplazar la fecha/divisa actual. A la vez, alternar USD/EUR durante la primera carga no debe descartar el único resultado BCV y dejar un spinner indefinido: ambos comparten el mismo par de tasas.
- Mantener un único ViewModel al abrir/cerrar hojas. Ninguna extracción visual debe originar otro repositorio con descargas duplicadas.

## 7. Secuencia de trabajo y salidas verificables

### Fase 0 — Reproducción y diagnóstico de los dos bloqueos

- [ ] Identificar versión/hash del APK probado, teléfono, Android y launcher; asociarlos a los logs.
- [ ] Guardar fixtures sintéticas y recorrido cámara/galería que reproduce OCR.
- [ ] Añadir identificación por etapa y captura del error original del OCR.
- [ ] Capturar el fallo del host 4×2 y ensayar `RemoteViews.apply()`.

**Salida:** OCR localizado por etapa y widget localizado por inflación/provider, con evidencia. El diseño UI de este documento puede implementarse mientras se obtiene hardware; no marcar los bloqueos como resueltos si faltan sus reproducciones.

### Fase 1 — Recuperar OCR y widget con cambios acotados

- [ ] Corregir el XML incompatible y probar vacío/actualización en Android.
- [ ] Reparar la causa observada del OCR y el cierre que puede ocultar errores.
- [ ] Completar contrato de imagen compartida y revisar cámara/galería recuperada.
- [ ] Confirmar reconocimiento offline y selección sobre una foto real.

**Salida:** ambas funciones dejan de fallar en el dispositivo de prueba con release; log y evidencia visual antes/después. No basta un nuevo texto de error.

### Fase 2 — Nueva pantalla principal

- [ ] Extraer panel de conversión y resumen de contexto sin duplicar estado.
- [ ] Implementar los bocetos de reposo/escritura; eliminar cabecera duplicada, tabla previa al campo y atajos predeterminados.
- [ ] Añadir hoja «Tasas y fecha» y pantalla de Ajustes.
- [ ] Mantener acceso OCR con monto escrito, foco, copia, limpieza y teclado.
- [ ] Corregir inserción programática y carreras de moneda/fecha durante edición.
- [ ] Validar claro/oscuro, contraste de sistema, cantidades largas y texto ampliado.

**Salida:** escribir y ver el resultado es el recorrido dominante; no requiere bajar por tasas/calendario para alcanzar el campo.

### Fase 3 — Consolidar widgets y recorrido completo

- [ ] Snapshot íntegro, migración V1 y fallos de publicación observables.
- [ ] Resize, tema, alta/baja y programación del trabajo con app cerrada.
- [ ] Validar que histórico/USDT no contaminan el snapshot oficial.
- [ ] Confirmar foto → selección → moneda → conversión → actualización de widget.

**Salida:** render fiable y metadatos veraces tanto con app abierta como cerrada, sin prometer exactitud horaria del scheduler.

### Fase 4 — Entrega y documentación

- [ ] Ejecutar análisis y pruebas apropiadas, incluyendo pruebas Android que crucen los límites nativos.
- [ ] Compilar release ARM64 e inspeccionar ABI y manifiesto; probar ese mismo APK, no solo uno debug.
- [ ] Documentar causa raíz final de cada incidente, comandos ejecutados, resultado y dispositivo/launcher.
- [ ] Actualizar `doc.md`, `funciones.md`, ADR y estado del plan según lo realmente verificado; mantener los pendientes explícitos.

## 8. Matriz de aceptación

| Área | Prueba | Aceptación |
|---|---|---|
| Inicio | Arranque 360×640, texto 100% | Campo en el primer tercio del área útil; tabla detallada y calendario no lo preceden. |
| Teclado | Foco con inset de 280 dp | Campo y resultado/copiar visibles y operables, sin scroll manual. Verificar rectángulos/hit testing, no solo `findsOneWidget`. |
| Edición | Escribir, seleccionar, borrar, pegar, invertir, cambiar moneda | Texto mostrado, monto calculado y cursor coherentes; teclado estable. |
| Programático | OCR/intercambio con coma automática activa | Monto no dividido otra vez entre cien; edición posterior predecible. |
| Tamaños | 320/360/390 dp, landscape, texto 100/130/200% | Sin overflow ni controles inaccesibles; scroll permitido cuando haga falta. |
| Cantidades | Número largo, cero, coma/punto incompleto | Dígitos consultables, cero calculable y ausencia de resultados anteriores en entrada incompleta. |
| Navegación | Tasas/fecha/ajustes y volver | Monto conservado; fecha aplicada visible; no se repiten cargas por abrir una hoja. |
| Concurrencia | USD↔EUR↔USDT durante carga inicial e histórico | No spinner indefinido ni respuesta/metadata de otro contexto. |
| Estados | Caché normal, fallo de proveedor, dato antiguo, sin dato | Mensajes distintos y compactos; nunca «recién actualizada» por leer caché. |
| OCR de archivo | PNG de captura y JPEG de galería reales | Pipeline completo en Android, copia y transferencia correctas. |
| OCR de cámara | Captura propia, permiso denegado, cancelar/reabrir | Reconocimiento operativo o recuperación específica; recursos liberados. |
| OCR offline | Primera ejecución release sin red con fixture local | Modelo Latin reconoce; no depende de descargar un modelo al usarlo. |
| OCR de geometría | EXIF 90/180/270°, espejado, zoom/pan | Foto, regiones y toque alineados. |
| OCR de texto | Sin números, sin texto, repetidos con distinta moneda | Texto arbitrario copiable; vacío no es error técnico; identidad de candidatos conservada. |
| OCR de errores | Archivo inválido, fallo nativo, fallo al cerrar | Etapa/causa registradas; no se oculta el fallo primario ni se pierde un resultado correcto solo por cierre. |
| Widget de layout | `RemoteViews.apply()` y añadir en launcher | 4×2 y compacto inflan incluso sin datos; no aparece el error del host. |
| Widget de lectura | Datos V1, JSON nuevo, snapshot inválido/interrumpido | Último dato íntegro o estado vacío recuperable; nunca mezcla de cotizaciones. |
| Widget de tamaño | 4×2, mínimo permitido y redimensionado | Valores completos y fecha legible; metadatos secundarios adaptados. |
| Widget de lifecycle | Dos instancias, quitar una/última, proceso cerrado, reinicio | Programación única correcta y clic funcional; alta no depende siempre de abrir manualmente la app. |
| Widget de contexto | Ver histórico/próxima/USDT en app | Launcher conserva cotización oficial actual. |
| Widget de fondo | Offline, retorno de red y Doze | Persiste el último dato y su fecha; horario aproximado y sin falsa frescura. |

### Evidencias mínimas de cierre

- Capturas del inicio nuevo con y sin teclado, en claro y oscuro.
- Grabación o secuencia reproducible de foto/galería → OCR → copiar/usar monto.
- Captura del 4×2 vacío y con tasas en un launcher real, y registro de actualización con app cerrada.
- Resultado de análisis, pruebas Dart/Flutter, prueba nativa de RemoteViews y smoke test OCR nativo.
- APK identificado por hash, versión y ABI; mismos bytes usados en el ensayo final.

## 9. Guía de diagnóstico para la implementación

Comandos de referencia, **no ejecutados por este plan**. Ajustar rutas de SDK/dispositivo al entorno:

```bash
adb devices -l
adb shell getprop ro.build.version.release
adb shell dumpsys package ve.cuantoes.cuantoes

# Capturar y después reproducir; el fallo del widget puede estar en el launcher.
adb logcat -v threadtime > /tmp/opencode/cuantoes-v2-device.log

adb shell dumpsys appwidget
adb shell dumpsys jobscheduler

flutter analyze --no-pub
flutter test --no-pub
make build-apk
sha256sum build/app/outputs/flutter-apk/app-release.apk
```

Ampliar el Makefile existente para las comprobaciones Android/integración cuando se creen. Las pruebas de ML Kit deben ejecutar el plugin real; las del widget deben aplicar RemoteViews, no construir únicamente un modelo Dart.

## 10. Referencias y encargo de implementación

- [Plan y auditoría anteriores](auditoria-y-plan-luna.md).
- [Contexto activo](ai-context.md), [catálogo de funciones](funciones.md), [ADRs](decisiones.md).
- [Android RemoteViews: clases admitidas](https://developer.android.com/reference/android/widget/RemoteViews).
- [Android: crear App Widgets](https://developer.android.com/develop/ui/views/appwidgets).
- [Android: actualización de widgets](https://developer.android.com/develop/ui/views/appwidgets/advanced).
- [ML Kit: reconocimiento de texto Android](https://developers.google.com/ml-kit/vision/text-recognition/v2/android).
- Adaptadores instalados revisados: `google_mlkit_text_recognition-0.17.1` (`TextRecognizer.kt`, `text_recognizer.dart`) y `google_mlkit_commons-0.13.0` (`InputImageConverter.kt`, `rect.dart`).

> Implementa este plan V2 sobre el checkout actual. Prioriza un inicio donde monto y resultado permanezcan visibles al escribir, con tasas/calendario en una hoja y ajustes en una pantalla compacta. Reproduce y captura el error real del OCR antes de cambiar dependencias; valida archivo → ML Kit nativo → selección → transferencia. Investiga primero el `<View>` incompatible de `widget_bcv.xml` y comprueba inflación real de RemoteViews. Conserva la cascada de proveedores y la separación USDT/BCV. Usa las fases y matriz para registrar qué queda implementado, qué está probado y qué sigue pendiente; un build o mocks exitosos no cierran los dos incidentes nativos.
