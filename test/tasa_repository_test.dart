import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cuantoes/models/tasa_bcv.dart';
import 'package:cuantoes/services/bcv_api_service.dart';
import 'package:cuantoes/services/bcv_cache_service.dart';
import 'package:cuantoes/services/bcv_scraper_service.dart';
import 'package:cuantoes/services/tasa_repository.dart';
import 'package:cuantoes/utils/feriados_ve.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    setFeriadosGoogle({});
  });

  test('uses a prior effective rate as current on a holiday', () async {
    final ahora = ahoraVenezuela();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    setFeriadosGoogle({_claveFecha(hoy)});

    final actual = _tasa(DateTime(hoy.year, hoy.month, hoy.day - 1), 100, 110);
    final cache = BcvCacheService();
    await cache.guardarTasa(actual);
    final api = _FakeApi();
    final repository = TasaRepository(
      api: api,
      scraper: _FakeScraper(),
      cache: cache,
    );

    final result = await repository.obtenerTasa();

    expect(result.usd, actual.usd);
    expect(result.fechaEfectiva, actual.fechaEfectiva);
    expect(api.realtimeCalls, 0);
  });

  test('cache ignores a weekend effective entry', () async {
    final viernes = DateTime(2026, 9, 4);
    final sabado = DateTime(2026, 9, 5);
    final cache = BcvCacheService();
    await cache.guardarTasa(_tasa(viernes, 100, 110));
    await cache.guardarTasa(_tasa(sabado, 200, 220));

    final result = await cache.obtenerTasaMasRecienteHasta(
      DateTime(2026, 9, 6),
    );

    expect(result?.usd, 100);
    expect(result?.fechaEfectiva, viernes);
  });

  test(
    'historical lookup prefers the API before a prior cache fallback',
    () async {
      final requested = DateTime(2026, 9, 6);
      final cached = _tasa(DateTime(2026, 9, 4), 100, 110);
      final apiRate = _tasa(DateTime(2026, 9, 4), 101, 111);
      final cache = BcvCacheService();
      await cache.guardarTasa(cached);
      final api = _FakeApi()..historical = apiRate;
      final repository = TasaRepository(
        api: api,
        scraper: _FakeScraper(),
        cache: cache,
      );

      final result = await repository.obtenerTasaHistorica(requested);

      expect(result?.usd, apiRate.usd);
      expect(api.historicalCalls, 1);
    },
  );

  test('historical lookup uses exact cache without calling the API', () async {
    final requested = DateTime(2026, 9, 8);
    final cached = _tasa(requested, 100, 110);
    final cache = BcvCacheService();
    await cache.guardarTasa(cached);
    final api = _FakeApi()..historical = _tasa(requested, 101, 111);
    final repository = TasaRepository(
      api: api,
      scraper: _FakeScraper(),
      cache: cache,
    );

    final result = await repository.obtenerTasaHistorica(requested);

    expect(result?.usd, cached.usd);
    expect(api.historicalCalls, 0);
  });

  test(
    'previous lookup ignores stale cache and falls back to the API',
    () async {
      final limite = DateTime(2026, 9, 8);
      final stale = _tasa(DateTime(2026, 9, 4), 100, 110);
      final apiRate = _tasa(DateTime(2026, 9, 7), 101, 111);
      final cache = BcvCacheService();
      await cache.guardarTasa(stale);
      final api = _FakeApi()..previous = apiRate;
      final repository = TasaRepository(
        api: api,
        scraper: _FakeScraper(),
        cache: cache,
      );

      final result = await repository.obtenerTasaAnterior(limite);

      expect(result?.usd, apiRate.usd);
      expect(api.previousCalls, 1);
    },
  );

  test('previous lookup prefers the immediately prior business date', () async {
    final limite = DateTime(2026, 9, 7);
    final previous = _tasa(DateTime(2026, 9, 4), 100, 110);
    final cache = BcvCacheService();
    await cache.guardarTasa(previous);
    final api = _FakeApi()..previous = _tasa(DateTime(2026, 9, 3), 90, 99);
    final repository = TasaRepository(
      api: api,
      scraper: _FakeScraper(),
      cache: cache,
    );

    final result = await repository.obtenerTasaAnterior(limite);

    expect(result?.usd, previous.usd);
    expect(api.previousCalls, 0);
  });
}

String _claveFecha(DateTime fecha) =>
    '${fecha.year}${fecha.month.toString().padLeft(2, '0')}${fecha.day.toString().padLeft(2, '0')}';

TasaBcv _tasa(DateTime fechaEfectiva, double usd, double eur) => TasaBcv(
  usd: usd,
  eur: eur,
  usdt: 0,
  fecha: fechaEfectiva,
  origen: 'test',
  fechaEfectiva: fechaEfectiva,
);

class _FakeApi extends BcvApiService {
  TasaBcv? historical;
  TasaBcv? previous;
  int realtimeCalls = 0;
  int historicalCalls = 0;
  int previousCalls = 0;

  @override
  Future<TasaBcv> obtenerTasa() async {
    realtimeCalls++;
    throw StateError('unexpected realtime call');
  }

  @override
  Future<TasaBcv?> obtenerTasaHistorica(DateTime fecha) async {
    historicalCalls++;
    return historical;
  }

  @override
  Future<TasaBcv?> obtenerTasaAnterior(DateTime fechaLimite) async {
    previousCalls++;
    return previous;
  }
}

class _FakeScraper extends BcvScraperService {}
