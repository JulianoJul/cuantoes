import '../models/tasa_bcv.dart';
import 'bcv_api_service.dart';
import 'bcv_cache_service.dart';

class TasaRepository {
  final BcvApiService _api;
  final BcvCacheService _cache;

  TasaRepository({
    BcvApiService? api,
    BcvCacheService? cache,
  })  : _api = api ?? BcvApiService(),
        _cache = cache ?? BcvCacheService();

  Future<TasaBcv> obtenerTasa() async {
    final cache = await _cache.obtenerTasa();
    if (cache != null && _esTasaVigente(cache.fecha)) {
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
      rethrow;
    }
  }

  Future<TasaBcv?> obtenerTasaHistorica(DateTime fecha) async {
    try {
      return await _api.obtenerTasaHistorica(fecha);
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

  bool _esTasaVigente(DateTime fecha) {
    final ahora = DateTime.now();
    final mismoDia = fecha.year == ahora.year &&
        fecha.month == ahora.month &&
        fecha.day == ahora.day;

    if (!mismoDia) return false;

    return ahora.hour < 22;
  }
}
