import '../models/tasa_bcv.dart';
import '../models/tasa_usdt.dart';
import 'bcv_scraper_service.dart';
import 'bcv_api_service.dart';
import 'bcv_cache_service.dart';

class TasaRepository {
  final BcvScraperService _scraper;
  final BcvApiService _api;
  final BcvCacheService _cache;

  TasaRepository({
    BcvScraperService? scraper,
    BcvApiService? api,
    BcvCacheService? cache,
  })  : _scraper = scraper ?? BcvScraperService(),
        _api = api ?? BcvApiService(),
        _cache = cache ?? BcvCacheService();

  Future<TasaBcv> obtenerTasa() async {
    final errores = <String>[];

    try {
      final tasa = await _api.obtenerTasa();
      await _cache.guardarTasa(tasa);
      return tasa;
    } catch (e) {
      errores.add('api: $e');
    }

    try {
      final tasa = await _scraper.obtenerTasa();
      await _cache.guardarTasa(tasa);
      return tasa;
    } catch (e) {
      errores.add('scraping: $e');
    }

    final tasaCache = await _cache.obtenerTasa();
    if (tasaCache != null) return tasaCache;

    throw Exception(
        'No se pudo obtener la tasa. Errores: ${errores.join(" | ")}');
  }

  Future<TasaBcv?> obtenerTasaHistorica(DateTime fecha) async {
    try {
      return await _api.obtenerTasaHistorica(fecha);
    } catch (_) {
      return null;
    }
  }

  Future<TasaUsdt?> obtenerTasaUsdt() async {
    try {
      return await _api.obtenerTasaUsdt();
    } catch (_) {
      return null;
    }
  }
}
