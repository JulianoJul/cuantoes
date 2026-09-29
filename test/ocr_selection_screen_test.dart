import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cuantoes/models/documento_ocr.dart';
import 'package:cuantoes/screens/ocr_selection_screen.dart';
import 'package:cuantoes/services/ocr_service.dart';

class _FakeOcrService extends OcrService {
  final DocumentoOcr documento;

  const _FakeOcrService(this.documento);

  @override
  Future<DocumentoOcr> reconocerDocumento(String rutaImagen) async => documento;
}

void main() {
  late Directory tempDir;
  late String imagePath;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('cuantoes-ocr-test-');
    imagePath = '${tempDir.path}/price.png';
    await File(imagePath).writeAsBytes(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      ),
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  testWidgets('texto accesible indica que su contenido se puede desplazar', (
    tester,
  ) async {
    final documento = DocumentoOcr(
      id: 'test',
      rutaImagen: imagePath,
      anchoImagen: 100,
      altoImagen: 100,
      textoCompleto: '4bs',
      regiones: [
        RegionOcr(
          id: 'b0l0e0',
          texto: '4bs',
          indice: 0,
          bloque: 0,
          linea: 0,
          elemento: 0,
          izquierda: 10,
          arriba: 10,
          ancho: 40,
          alto: 20,
          poligono: const [],
          monedaSugerida: 'VES',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: OcrSelectionScreen(
          rutaImagen: imagePath,
          servicio: _FakeOcrService(documento),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Despliega y desliza para recorrer todo'), findsOneWidget);
    await tester.tap(find.text('Texto accesible'));
    await tester.pumpAndSettle();
    expect(find.byType(Scrollbar), findsOneWidget);
  });
}
