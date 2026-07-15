import '../models/tasa_bcv.dart';
import 'bcv_api_service.dart';
import 'bcv_cache_service.dart';
import 'bcv_scraper_service.dart';

class TasaRepository {
  final BcvApiService _api;
  final BcvScraperService _scraper;
  final BcvCacheService _cache;

  TasaRepository({
    BcvApiService? api,
    BcvScraperService? scraper,
    BcvCacheService? cache,
  })  : _api = api ?? BcvApiService(),
        _scraper = scraper ?? BcvScraperService(),
        _cache = cache ?? BcvCacheService();

  Future<TasaBcv> obtenerTasa() async {
    final cache = await _cache.obtenerTasa();
    if (cache != null && _esTasaVigente(cache.fechaEfectiva)) {
      return cache;
    }

    return refrescarTasa();
  }

  Future<TasaBcv> refrescarTasa() async {
    try {
      final tasa = await _api.obtenerTasa();
      await _cache.guardarTasa(tasa);
      return tasa;
    } catch (_) {
      final cache = await _cache.obtenerTasa();
      if (cache != null) return cache;
      final scrape = await _scraper.obtenerTasa();
      if (scrape != null) {
        await _cache.guardarTasa(scrape);
        return scrape;
      }
      rethrow;
    }
  }

  Future<TasaBcv?> obtenerTasaHistorica(DateTime fecha) async {
    final ef = DateTime(fecha.year, fecha.month, fecha.day);

    final cache = await _cache.obtenerTasaPorFecha(ef);
    if (cache != null) return cache;

    try {
      final tasa = await _api.obtenerTasaHistorica(fecha);
      if (tasa != null) {
        await _cache.guardarTasa(tasa);
      }
      return tasa;
    } catch (_) {
      return null;
    }
  }

  Future<TasaBcv?> obtenerTasaAnterior(DateTime fechaLimite) async {
    final cache = await _cache.obtenerTasaMasRecienteMenorQue(fechaLimite);
    if (cache != null) return cache;

    try {
      final tasa = await _api.obtenerTasaAnterior(fechaLimite);
      if (tasa != null) {
        await _cache.guardarTasa(tasa);
      }
      return tasa;
    } catch (_) {
      return null;
    }
  }

  Future<double?> obtenerUsdt() async {
    try {
      return await _api.obtenerUsdt();
    } catch (_) {
      return null;
    }
  }

  bool _esTasaVigente(DateTime fechaEfectiva) {
    final ahora = DateTime.now();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);

    if (fechaEfectiva.isBefore(hoy)) return false;
    if (fechaEfectiva.isAfter(hoy)) return true;

    return ahora.hour < 14;
  }
}
