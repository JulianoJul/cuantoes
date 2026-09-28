import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'package:cuantoes/services/ocr_service.dart';
import 'package:cuantoes/utils/ocr_coordinate_mapper.dart';
import 'package:cuantoes/models/documento_ocr.dart';

void main() {
  test('OCR conserva regiones, orden, geometría y divisa contextual', () {
    final moneda = _elemento('Bs.', 10, 20, 24, 12);
    final monto = _elemento('185,00', 40, 20, 48, 12);
    final linea = TextLine(
      text: 'Bs. 185,00',
      elements: [moneda, monto],
      boundingBox: const Rect.fromLTWH(10, 20, 78, 12),
      recognizedLanguages: const [],
      cornerPoints: const [],
      confidence: 0.98,
      angle: 0,
    );
    final documento = const OcrService().documentoDesdeResultado(
      rutaImagen: '/tmp/ticket.jpg',
      anchoImagen: 300,
      altoImagen: 600,
      reconocido: RecognizedText(
        text: 'Bs. 185,00',
        blocks: [
          TextBlock(
            text: 'Bs. 185,00',
            lines: [linea],
            boundingBox: const Rect.fromLTWH(10, 20, 78, 12),
            recognizedLanguages: const [],
            cornerPoints: const [],
          ),
        ],
      ),
    );

    expect(documento.regiones, hasLength(2));
    expect(documento.regiones[1].texto, '185,00');
    expect(documento.regiones[1].izquierda, 40);
    expect(documento.regiones[1].monedaSugerida, 'VES');
    expect(documento.regiones[1].id, isNot(documento.regiones[0].id));
  });

  test('OCR conserva la divisa contextual de importes repetidos', () {
    final textoLinea = 'USD 10 EUR 10';
    final linea = TextLine(
      text: textoLinea,
      elements: [
        _elemento('USD', 0, 0, 20, 12),
        _elemento('10', 24, 0, 15, 12),
        _elemento('EUR', 45, 0, 20, 12),
        _elemento('10', 70, 0, 15, 12),
      ],
      boundingBox: const Rect.fromLTWH(0, 0, 85, 12),
      recognizedLanguages: const [],
      cornerPoints: const [],
      confidence: 0.98,
      angle: 0,
    );
    final documento = const OcrService().documentoDesdeResultado(
      rutaImagen: '/tmp/ticket.jpg',
      anchoImagen: 300,
      altoImagen: 600,
      reconocido: RecognizedText(
        text: textoLinea,
        blocks: [
          TextBlock(
            text: textoLinea,
            lines: [linea],
            boundingBox: const Rect.fromLTWH(0, 0, 85, 12),
            recognizedLanguages: const [],
            cornerPoints: const [],
          ),
        ],
      ),
    );

    expect(documento.regiones[1].texto, '10');
    expect(documento.regiones[1].monedaSugerida, 'USD');
    expect(documento.regiones[3].texto, '10');
    expect(documento.regiones[3].monedaSugerida, 'EUR');
  });

  test('el mapper BoxFit.contain invierte posiciones con bandas laterales', () {
    const mapper = OcrCoordinateMapper(
      anchoImagen: 100,
      altoImagen: 200,
      anchoVista: 300,
      altoVista: 300,
    );
    final region = RegionOcr(
      id: 'r1',
      texto: 'precio',
      indice: 0,
      bloque: 0,
      linea: 0,
      elemento: 0,
      izquierda: 10,
      arriba: 20,
      ancho: 20,
      alto: 10,
      poligono: [],
    );

    final rect = mapper.mapearRectangulo(region);
    expect(mapper.escala, 1.5);
    expect(rect.izquierda, 90);
    expect(rect.arriba, 30);
    final imagen = mapper.aCoordenadasImagen(const PuntoVistaOcr(90, 30));
    expect(imagen.x, 10);
    expect(imagen.y, 20);
  });
}

TextElement _elemento(String texto, int x, int y, int width, int height) =>
    TextElement(
      text: texto,
      symbols: const [],
      boundingBox: Rect.fromLTWH(
        x.toDouble(),
        y.toDouble(),
        width.toDouble(),
        height.toDouble(),
      ),
      recognizedLanguages: const [],
      cornerPoints: [
        Point<int>(x, y),
        Point<int>(x + width, y),
        Point<int>(x + width, y + height),
        Point<int>(x, y + height),
      ],
      confidence: 0.97,
      angle: 0,
    );
