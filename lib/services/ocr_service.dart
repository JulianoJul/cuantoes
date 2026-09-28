import 'dart:io';
import 'dart:ui' as ui;

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../models/documento_ocr.dart';
import '../utils/numeros_ocr.dart';

class OcrService {
  const OcrService();

  Future<DocumentoOcr> reconocerDocumento(String rutaImagen) async {
    final bytes = await File(rutaImagen).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final image = (await codec.getNextFrame()).image;
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final input = InputImage.fromFilePath(rutaImagen);
      final reconocido = await recognizer.processImage(input);
      return documentoDesdeResultado(
        rutaImagen: rutaImagen,
        anchoImagen: image.width,
        altoImagen: image.height,
        reconocido: reconocido,
      );
    } finally {
      image.dispose();
      codec.dispose();
      await recognizer.close();
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
