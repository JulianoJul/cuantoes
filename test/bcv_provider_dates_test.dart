import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:cuantoes/services/bcv_api_service.dart';
import 'package:cuantoes/services/bcv_scraper_service.dart';

void main() {
  test('normalizes offset-less Rafnix timestamps at the cutoff', () async {
    final client = MockClient(
      (request) async => http.Response(
        jsonEncode([
          {'currency': 'dolar', 'rate': 100, 'date': '2026-09-08T18:00:00'},
          {'currency': 'euro', 'rate': 200, 'date': '2026-09-08T18:00:00'},
        ]),
        200,
      ),
    );

    final tasa = await BcvApiService(client: client).obtenerTasa();

    expect(tasa.fecha, DateTime.utc(2026, 9, 8, 18));
    expect(tasa.fechaEfectiva, DateTime(2026, 9, 9));
  });

  test(
    'uses the normalized effective day for realtime USD/EUR consistency',
    () async {
      final client = MockClient(
        (request) async => http.Response(
          jsonEncode([
            {'currency': 'dolar', 'rate': 100, 'date': '2026-09-08T17:59:00'},
            {'currency': 'euro', 'rate': 200, 'date': '2026-09-08T18:00:00'},
          ]),
          200,
        ),
      );

      expect(
        BcvApiService(client: client).obtenerTasa(),
        throwsA(
          predicate<Object>(
            (error) => error.toString().contains('fechas efectivas distintas'),
          ),
        ),
      );
    },
  );

  test('stores scraper Fecha Valor as the effective date', () async {
    final client = MockClient(
      (request) async => http.Response('''
          <div id="dolar"><span>USD</span><strong>1.234,45</strong></div>
          <div id="euro"><span>EUR</span><strong>2.345,56</strong></div>
          <p>Fecha Valor: <span>Miércoles, 8 Septiembre 2026</span></p>
          ''', 200),
    );

    final tasa = await BcvScraperService(client: client).obtenerTasa();

    expect(tasa, isNotNull);
    expect(tasa!.usd, 1234.45);
    expect(tasa.eur, 2345.56);
    expect(tasa.fecha, DateTime(2026, 9, 8));
    expect(tasa.fechaEfectiva, DateTime(2026, 9, 8));
  });
}
