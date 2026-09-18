import 'package:flutter_test/flutter_test.dart';

import 'package:cuantoes/utils/numeros_ocr.dart';

void main() {
  test('parsea formato venezolano con miles y decimales', () {
    expect(parsearNumero('1.234,56'), closeTo(1234.56, 0.0001));
    expect(parsearNumero('848,5458'), closeTo(848.5458, 0.0001));
    expect(parsearNumero('25,00'), 25);
    expect(parsearNumero('0,5'), 0.5);
  });

  test('parsea formato inglés', () {
    expect(parsearNumero('1,234.56'), closeTo(1234.56, 0.0001));
    expect(parsearNumero('10.50'), 10.5);
  });

  test('un separador único con 3 dígitos se interpreta como miles', () {
    expect(parsearNumero('1.234'), 1234);
    expect(parsearNumero('1,234'), 1234);
  });

  test('ignora texto sin números válidos', () {
    expect(parsearNumero('Bs.'), isNull);
    expect(extraerNumeros('Precio total'), isEmpty);
  });

  test('extrae números en orden, sin repetidos y con su token original', () {
    final numeros = extraerNumeros('Bs. 848,5458 y USD 10.50; repetido 10,50');

    expect(numeros.length, 2);
    expect(numeros[0].texto, '848,5458');
    expect(numeros[0].valor, closeTo(848.5458, 0.0001));
    expect(numeros[1].texto, '10.50');
    expect(numeros[1].valor, 10.5);
  });

  test('extrae números de un texto multilínea tipo captura', () {
    final numeros = extraerNumeros('''
      Tasa BCV
      USD 1 = Bs. 848,5458
      EUR 1 = Bs. 974,4191
    ''');

    expect(numeros.length, 3);
    expect(numeros[0].valor, 1);
    expect(numeros[1].valor, closeTo(848.5458, 0.0001));
    expect(numeros[2].valor, closeTo(974.4191, 0.0001));
  });
}
