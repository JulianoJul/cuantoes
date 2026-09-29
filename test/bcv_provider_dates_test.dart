import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:cuantoes/services/bcv_api_service.dart';
import 'package:cuantoes/services/bcv_today_service.dart';
import 'package:cuantoes/services/chitty_bcv_service.dart';
import 'package:cuantoes/utils/feriados_ve.dart';

void main() {
  test('DolarAPI parses the official USD and EUR endpoints', () async {
    final client = MockClient((request) async {
      final isUsd = request.url.path.contains('/dolares/');
      return http.Response(
        jsonEncode({
          'promedio': isUsd ? 855.6625 : 972.648677,
          'fechaActualizacion': '2026-09-25T00:00:00-04:00',
        }),
        200,
      );
    });

    final tasa = await DolarApiService(client: client).obtenerTasa();

    expect(tasa.usd, 855.6625);
    expect(tasa.eur, 972.648677);
    expect(tasa.origen, 'dolarapi');
    expect(tasa.fechaEfectiva, DateTime(2026, 9, 25));
  });

  test('DolarAPI rejects USD and EUR from different dates', () async {
    final client = MockClient((request) async {
      final isUsd = request.url.path.contains('/dolares/');
      return http.Response(
        jsonEncode({
          'promedio': isUsd ? 100 : 200,
          'fechaActualizacion': isUsd
              ? '2026-09-25T00:00:00-04:00'
              : '2026-09-26T00:00:00-04:00',
        }),
        200,
      );
    });

    expect(
      DolarApiService(client: client).obtenerTasa(),
      throwsA(
        predicate<Object>(
          (error) => error.toString().contains('fechas distintas'),
        ),
      ),
    );
  });

  test('BCV Today parses the static current snapshot', () async {
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'USD': 855.6625,
          'EUR': 972.648677,
          'updated_at': '2026-09-24T21:38:56.194100+00:00',
          'effective_date': '2026-09-25',
          'date': '2026-09-27',
        }),
        200,
      ),
    );

    final tasa = await BcvTodayService(client: client).obtenerTasa();

    expect(tasa.usd, 855.6625);
    expect(tasa.eur, 972.648677);
    expect(tasa.origen, 'bcv_today');
    expect(tasa.fechaEfectiva, DateTime(2026, 9, 25));
  });

  test('BCV Today reads a historical daily snapshot', () async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/history/2026-09-08.json')) {
        return http.Response(
          jsonEncode({
            'USD': 100,
            'EUR': 200,
            'updated_at': '2026-09-07T20:00:00Z',
            'effective_date': '2026-09-08',
            'date': '2026-09-08',
          }),
          200,
        );
      }
      return http.Response('{}', 404);
    });

    final tasa = await BcvTodayService(
      client: client,
    ).obtenerTasaHistorica(DateTime(2026, 9, 8));

    expect(tasa?.usd, 100);
    expect(tasa?.eur, 200);
    expect(tasa?.fechaEfectiva, DateTime(2026, 9, 8));
  });

  test('Chitty BCV parses the current fallback dataset', () async {
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'updated_at': '2026-09-26T09:43:29Z',
          'tasas': {'usd': 855.6625, 'eur': 972.648677},
        }),
        200,
      ),
    );

    final tasa = await ChittyBcvService(client: client).obtenerTasa();

    expect(tasa.usd, 855.6625);
    expect(tasa.eur, 972.648677);
    expect(tasa.origen, 'chitty_bcv');
    expect(tasa.fechaEfectiva, DateTime(2026, 9, 25));
  });

  test(
    'Chitty obtiene la tasa adelantada sin consultar antes la actual',
    () async {
      final ahora = ahoraVenezuela();
      final siguiente = proximoDiaHabil(
        DateTime(ahora.year, ahora.month, ahora.day + 1),
      );
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode({
            'adelantada': {
              'usd': 120,
              'eur': 130,
              'aplica_desde': siguiente.toIso8601String(),
            },
          }),
          200,
        ),
      );

      final tasa = await ChittyBcvService(
        client: client,
      ).obtenerTasaSiguiente();

      expect(tasa?.usd, 120);
      expect(tasa?.fechaEfectiva, siguiente);
    },
  );
}
