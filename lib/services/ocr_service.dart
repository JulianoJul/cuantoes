import 'dart:io';
import 'dart:developer' as developer;
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show PlatformException;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../models/documento_ocr.dart';
import '../utils/numeros_ocr.dart';

enum OcrEtapa { lectura, decodificacion, reconocimiento, adaptacion }

class OcrException implements Exception {
  final OcrEtapa etapa;
  final Object causa;

  const OcrException({required this.etapa, required this.causa});

  String get mensajeUsuario => switch (etapa) {
    OcrEtapa.lectura => 'No se pudo abrir el archivo de imagen.',
    OcrEtapa.decodificacion => 'El formato de esta imagen no se pudo procesar.',
    OcrEtapa.reconocimiento => 'Falló el reconocimiento de texto en el dispositivo.',
    OcrEtapa.adaptacion => 'Se reconoció la imagen, pero no se pudieron preparar sus regiones.',
  };

  String get detalleTecnico => switch (causa) {
    PlatformException exception => 'PlatformException (${exception.code})',
    FileSystemException exception =>
      'FileSystemException (código ${exception.osError?.errorCode ?? 'desconocido'})',
    _ => causa.runtimeType.toString(),
  };

  @override
  String toString() => 'OcrException(${etapa.name}): $detalleTecnico';
}

class OcrService {
  const OcrService();

  Future<DocumentoOcr> reconocerDocumento(String rutaImagen) async {
    final operacion = DateTime.now().microsecondsSinceEpoch;
    final cronometro = Stopwatch()..start();
    OcrEtapa etapa = OcrEtapa.lectura;
    ui.Codec? codec;
    ui.Image? image;
    TextRecognizer? recognizer;
    try {
      final archivo = File(rutaImagen);
      if (!await archivo.exists()) {
        throw const FileSystemException('El archivo seleccionado ya no existe');
      }
      final bytes = await archivo.readAsBytes();
      if (bytes.isEmpty) {
        throw const FormatException('El archivo seleccionado está vacío');
      }

      etapa = OcrEtapa.decodificacion;
      final imageCodec = await ui.instantiateImageCodec(bytes);
      codec = imageCodec;
      final decodedImage = (await imageCodec.getNextFrame()).image;
      image = decodedImage;

      etapa = OcrEtapa.reconocimiento;
      final textRecognizer = TextRecognizer(
        script: TextRecognitionScript.latin,
      );
      recognizer = textRecognizer;
      final input = InputImage.fromFilePath(rutaImagen);
      final reconocido = await textRecognizer.processImage(input);

      etapa = OcrEtapa.adaptacion;
      final documento = documentoDesdeResultado(
        rutaImagen: rutaImagen,
        anchoImagen: decodedImage.width,
        altoImagen: decodedImage.height,
        reconocido: reconocido,
      );
      developer.log(
        'OCR completo id=$operacion bytes=${bytes.length} '
        'imagen=${decodedImage.width}x${decodedImage.height} '
        'regiones=${documento.regiones.length} '
        'duracionMs=${cronometro.elapsedMilliseconds}',
        name: 'cuantoes.ocr',
      );
      return documento;
    } catch (error, stackTrace) {
      final fallo = error is OcrException
          ? error
          : OcrException(etapa: etapa, causa: error);
      developer.log(
        'OCR fallido id=$operacion etapa=${fallo.etapa.name} '
        'duracionMs=${cronometro.elapsedMilliseconds}',
        name: 'cuantoes.ocr',
        error: fallo.detalleTecnico,
        stackTrace: StackTrace.fromString(
          stackTrace.toString().replaceAll(rutaImagen, '<imagen>'),
        ),
        level: 1000,
      );
      Error.throwWithStackTrace(fallo, stackTrace);
    } finally {
      try {
        image?.dispose();
      } catch (error, stackTrace) {
        developer.log(
          'No se pudo liberar la imagen decodificada id=$operacion',
          name: 'cuantoes.ocr',
          error: error,
          stackTrace: stackTrace,
          level: 900,
        );
      }
      try {
        codec?.dispose();
      } catch (error, stackTrace) {
        developer.log(
          'No se pudo liberar el codec id=$operacion',
          name: 'cuantoes.ocr',
          error: error,
          stackTrace: stackTrace,
          level: 900,
        );
      }
      try {
        await recognizer?.close();
      } catch (error, stackTrace) {
        // Un fallo al liberar el detector no debe ocultar el error primario
        // ni invalidar un resultado de OCR ya calculado.
        developer.log(
          'No se pudo cerrar el reconocedor id=$operacion',
          name: 'cuantoes.ocr',
          error: error,
          stackTrace: stackTrace,
          level: 900,
        );
      }
    }
  }

  DocumentoOcr documentoDesdeResultado({
    required String rutaImagen,
    required int anchoImagen,
    required int altoImagen,
    required RecognizedText reconocido,
  }) {
    final regiones = <RegionOcr>[];
    for (var bloque = 0; bloque < reconocido.blocks.length; bloque++) {
      final textBlock = reconocido.blocks[bloque];
      for (var linea = 0; linea < textBlock.lines.length; linea++) {
        final textLine = textBlock.lines[linea];
        final candidatos = extraerNumeros(textLine.text);
        final elementos = textLine.elements;
        var posicionTexto = 0;

        if (elementos.isEmpty) {
          regiones.add(
            _crearRegion(
              id: 'b${bloque}l${linea}e0',
              texto: textLine.text,
              indice: regiones.length,
              bloque: bloque,
              linea: linea,
              elemento: 0,
              caja: textLine.boundingBox,
              puntos: textLine.cornerPoints,
              confianza: textLine.confidence,
              monedaSugerida: null,
            ),
          );
          continue;
        }

        for (var elemento = 0; elemento < elementos.length; elemento++) {
          final word = elementos[elemento];
          final encontrado = textLine.text.indexOf(word.text, posicionTexto);
          final inicio = encontrado >= 0 ? encontrado : posicionTexto;
          final fin = inicio + word.text.length;
          final candidato = candidatos.cast<NumeroDetectado?>().firstWhere(
            (numero) =>
                numero != null && numero.inicio >= inicio && numero.fin <= fin,
            orElse: () => null,
          );
          if (encontrado >= 0) posicionTexto = fin;
          regiones.add(
            _crearRegion(
              id: 'b${bloque}l${linea}e$elemento',
              texto: word.text,
              indice: regiones.length,
              bloque: bloque,
              linea: linea,
              elemento: elemento,
              caja: word.boundingBox,
              puntos: word.cornerPoints,
              confianza: word.confidence,
              monedaSugerida: candidato?.monedaSugerida,
            ),
          );
        }
      }
    }

    return DocumentoOcr(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      rutaImagen: rutaImagen,
      anchoImagen: anchoImagen,
      altoImagen: altoImagen,
      textoCompleto: reconocido.text,
      regiones: regiones,
    );
  }

  RegionOcr _crearRegion({
    required String id,
    required String texto,
    required int indice,
    required int bloque,
    required int linea,
    required int elemento,
    required ui.Rect caja,
    required List<dynamic> puntos,
    required double? confianza,
    required String? monedaSugerida,
  }) {
    return RegionOcr(
      id: id,
      texto: texto,
      indice: indice,
      bloque: bloque,
      linea: linea,
      elemento: elemento,
      izquierda: caja.left,
      arriba: caja.top,
      ancho: caja.width,
      alto: caja.height,
      poligono: [
        for (final punto in puntos)
          PuntoOcr(punto.x.toDouble(), punto.y.toDouble()),
      ],
      confianza: confianza,
      monedaSugerida: monedaSugerida,
    );
  }

  /// Compatibilidad temporal para consumidores que solo necesitan texto plano.
  Future<String> reconocerTexto(String rutaImagen) async =>
      (await reconocerDocumento(rutaImagen)).textoCompleto;
}
