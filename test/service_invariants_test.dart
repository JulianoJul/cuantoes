import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cuantoes/models/tasa_bcv.dart';
import 'package:cuantoes/services/bcv_api_service.dart';
import 'package:cuantoes/services/bcv_cache_service.dart';
import 'package:cuantoes/services/bcv_provider.dart';
import 'package:cuantoes/services/tasa_repository.dart';
import 'package:cuantoes/utils/feriados_ve.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('current selection ignores future cache during cooldown', () async {
    final cache = BcvCacheService();
    final hoy = _hoyVenezuela();
    final actual = _tasa(_diaHabilAnterior(hoy), 100, 110);
    final futura = _tasa(hoy.add(const Duration(days: 1)), 200, 220);
    await cache.guardarTasa(actual);
    await cache.guardarTasa(futura);
    await cache.registrarConsulta();

    final cachedCurrent = await cache.obtenerTasa();
    expect(cachedCurrent?.usd, actual.usd);

    final api = _FakeApi()..realtime = futura;
    final repository = TasaRepository(
      api: api,
      cache: cache,
    );

    final result = await repository.obtenerTasa();

    expect(result.usd, actual.usd);
    expect(_dia(result.fechaEfectiva), _dia(actual.fechaEfectiva));
    expect(api.realtimeCalls, 0);
  });

  test(
    'network errors return current cache, never a future cache entry',
    () async {
      final cache = BcvCacheService();
      final hoy = _hoyVenezuela();
      final actual = _tasa(_diaHabilAnterior(hoy), 100, 110);
      final futura = _tasa(proximoDiaHabil(hoy.add(const Duration(days: 1))), 200, 220);
      await cache.guardarTasa(actual);
      await cache.guardarTasa(futura);

      final api = _FakeApi()..realtimeError = Exception('offline');
      final repository = TasaRepository(
        api: api,
        cache: cache,
      );

      final result = await repository.refrescarTasa();

      expect(result.usd, actual.usd);
      expect(_dia(result.fechaEfectiva), _dia(actual.fechaEfectiva));
    },
  );

  test(
    'repeated future refreshes preserve today and expose nearest next rate',
    () async {
      final cache = BcvCacheService();
      final hoy = _hoyVenezuela();
      final actual = _tasa(_diaHabilAnterior(hoy), 100, 110);
      final futura = _tasa(proximoDiaHabil(hoy.add(const Duration(days: 1))), 200, 220);
      await cache.guardarTasa(actual);

      final api = _FakeApi()..realtime = futura;
      final repository = TasaRepository(
        api: api,
        cache: cache,
      );

      await repository.refrescarTasa();
      await repository.refrescarTasa();

      final cachedToday = await cache.obtenerTasaPorFecha(actual.fechaEfectiva);
      final next = await repository.obtenerTasaSiguiente();

      expect(cachedToday?.usd, actual.usd);
      expect(next?.usd, futura.usd);
      expect(_dia(next!.fechaEfectiva), _dia(futura.fechaEfectiva));
    },
  );

  test(
    'fresh install with a future realtime rate recovers today from history',
    () async {
      final cache = BcvCacheService();
      final hoy = _hoyVenezuela();
      final actual = _tasa(_diaHabilAnterior(hoy), 100, 110);
      final futura = _tasa(proximoDiaHabil(hoy.add(const Duration(days: 1))), 200, 220);

      final api = _FakeApi()
        ..realtime = futura
        ..historical = actual;
      final repository = TasaRepository(
        api: api,
        cache: cache,
      );

      final result = await repository.refrescarTasa();

      expect(result.usd, actual.usd);
    expect(_dia(result.fechaEfectiva), _dia(actual.fechaEfectiva));
    },
  );

  test(
    'historical cache lookup returns the latest prior effective entry',
    () async {
      final cache = BcvCacheService();
      final viernes = DateTime(2026, 9, 4);
      final jueves = DateTime(2026, 9, 3);
      await cache.guardarTasa(_tasa(jueves, 90, 99));
      await cache.guardarTasa(_tasa(viernes, 100, 110));
      await cache.guardarTasa(_tasa(DateTime(2026, 9, 7), 200, 220));

      final repository = TasaRepository(
        api: _FakeApi(),
        cache: cache,
      );
      final result = await repository.obtenerTasaHistorica(
        DateTime(2026, 9, 6),
      );

      expect(result?.usd, 100);
      expect(_dia(result!.fechaEfectiva), viernes);
    },
  );

  test('historical lookup rejects a future API result', () async {
    final requested = DateTime(2026, 9, 6);
    final api = _FakeApi()..historical = _tasa(DateTime(2026, 9, 7), 200, 220);
    final repository = TasaRepository(
      api: api,
      cache: BcvCacheService(),
    );

    final result = await repository.obtenerTasaHistorica(requested);

    expect(result, isNull);
  });

  test(
    'historical lookup prefers a closer cached rate over a sparse API result',
    () async {
      final cache = BcvCacheService();
      final jueves = DateTime(2026, 9, 10);
      final cacheada = _tasa(jueves, 100, 110);
      await cache.guardarTasa(cacheada);

      final api = _FakeApi()..historical = _tasa(DateTime(2026, 9, 9), 90, 99);
      final repository = TasaRepository(
        api: api,
        cache: cache,
      );

      final result = await repository.obtenerTasaHistorica(
        DateTime(2026, 9, 11),
      );

      expect(result?.usd, cacheada.usd);
      expect(_dia(result!.fechaEfectiva), jueves);
    },
  );

  test(
    'previous lookup prefers a closer cached rate over a sparse API result',
    () async {
      final cache = BcvCacheService();
      final viernes = DateTime(2026, 9, 11);
      final cacheada = _tasa(viernes, 100, 110);
      await cache.guardarTasa(cacheada);

      final api = _FakeApi()..previous = _tasa(DateTime(2026, 9, 9), 90, 99);
      final repository = TasaRepository(
        api: api,
        cache: cache,
      );

      final result = await repository.obtenerTasaAnterior(
        DateTime(2026, 9, 15),
      );

      expect(result?.usd, cacheada.usd);
      expect(_dia(result!.fechaEfectiva), viernes);
    },
  );

  test('previous lookup uses cache first and falls back to API', () async {
    final limite = DateTime(2026, 9, 8);
    final previous = _tasa(DateTime(2026, 9, 4), 100, 110);
    final api = _FakeApi()..previous = previous;
    final repository = TasaRepository(
      api: api,
      cache: BcvCacheService(),
    );

    final result = await repository.obtenerTasaAnterior(limite);

    expect(result?.usd, previous.usd);
    expect(_dia(result!.fechaEfectiva).isBefore(limite), isTrue);
    expect(api.previousCalls, 1);
  });

  test('refresh tries providers in order before using the cache', () async {
    final primary = _FakeProvider()..realtimeError = StateError('offline');
    final fallback = _FakeProvider()
      ..realtime = _tasa(DateTime(2026, 9, 25), 855.66, 972.64);
    final repository = TasaRepository(
      providers: [primary, fallback],
      cache: BcvCacheService(),
    );

    final result = await repository.refrescarTasa();

    expect(result.usd, 855.66);
    expect(primary.realtimeCalls, 1);
    expect(fallback.realtimeCalls, 1);
  });

  test('DolarAPI history chooses USD and EUR from one effective date', () async {
    final client = MockClient((request) async {
      final isUsd = request.url.path.contains('/dolares/');
      final rates = isUsd
          ? [
              {'promedio': 108, 'fecha': '2026-09-08'},
              {'promedio': 107, 'fecha': '2026-09-07'},
              {'promedio': 105, 'fecha': '2026-09-05'},
            ]
          : [
              {'promedio': 208, 'fecha': '2026-09-08'},
              {'promedio': 207, 'fecha': '2026-09-07'},
              {'promedio': 205, 'fecha': '2026-09-05'},
            ];
      return http.Response(jsonEncode(rates), 200);
    });
    final api = BcvApiService(client: client);

    final result = await api.obtenerTasaHistorica(DateTime(2026, 9, 8));

    expect(result?.usd, 108);
    expect(result?.eur, 208);
    expect(_dia(result!.fechaEfectiva), DateTime(2026, 9, 8));

    final previous = await api.obtenerTasaAnterior(DateTime(2026, 9, 8));
    expect(previous?.usd, 107);
    expect(previous?.eur, 207);
    expect(_dia(previous!.fechaEfectiva), DateTime(2026, 9, 7));
  });
}

DateTime _hoyVenezuela() {
  final ahora = ahoraVenezuela();
  return DateTime(ahora.year, ahora.month, ahora.day);
}

DateTime _dia(DateTime fecha) => DateTime(fecha.year, fecha.month, fecha.day);

DateTime _diaHabilAnterior(DateTime fecha) {
  var anterior = _dia(fecha.subtract(const Duration(days: 1)));
  while (anterior.weekday == DateTime.saturday ||
      anterior.weekday == DateTime.sunday ||
      esFeriadoBancario(anterior)) {
    anterior = anterior.subtract(const Duration(days: 1));
  }
  return anterior;
}

TasaBcv _tasa(DateTime fechaEfectiva, double usd, double eur) => TasaBcv(
  usd: usd,
  eur: eur,
  usdt: 0,
  fecha: fechaEfectiva,
  origen: 'test',
  fechaEfectiva: fechaEfectiva,
);

class _FakeApi extends BcvApiService {
  TasaBcv? realtime;
  TasaBcv? historical;
  TasaBcv? previous;
  Object? realtimeError;
  int realtimeCalls = 0;
  int previousCalls = 0;

  @override
  Future<TasaBcv> obtenerTasa() async {
    realtimeCalls++;
    if (realtimeError != null) throw realtimeError!;
    return realtime!;
  }

  @override
  Future<TasaBcv?> obtenerTasaHistorica(DateTime fecha) async => historical;

  @override
  Future<TasaBcv?> obtenerTasaAnterior(DateTime fecha) async {
    previousCalls++;
    return previous;
  }
}

class _FakeProvider implements BcvProvider {
  TasaBcv? realtime;
  Object? realtimeError;
  int realtimeCalls = 0;

  @override
  String get nombre => 'test';

  @override
  Future<TasaBcv> obtenerTasa() async {
    realtimeCalls++;
    if (realtimeError != null) throw realtimeError!;
    return realtime!;
  }

  @override
  Future<TasaBcv?> obtenerTasaHistorica(DateTime fecha) async => null;

  @override
  Future<TasaBcv?> obtenerTasaAnterior(DateTime fechaLimite) async => null;

  @override
  Future<double?> obtenerUsdt() async => null;
}
