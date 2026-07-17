import '../models/tasa_bcv.dart';
import '../utils/feriados_ve.dart';
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
    final ahora = ahoraVenezuela();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);

    // Buscar la tasa más reciente con fechaEfectiva <= hoy.
    // Si ya salió la de mañana (fechaEfectiva > hoy), la ignoramos aquí
    // y la dejamos como "siguiente disponible".
    final cacheHoy = await _cache.obtenerTasaMasRecienteMenorQue(
        hoy.add(const Duration(days: 1)));
    if (cacheHoy != null) {
      if (_esTasaVigente(cacheHoy.fechaEfectiva)) {
        return cacheHoy;
      }
      final ultimaConsulta = await _cache.obtenerUltimaConsulta();
      if (ultimaConsulta != null) {
        final diff = DateTime.now().toUtc().difference(ultimaConsulta).inMinutes;
        if (diff < 30) return cacheHoy;
      }
    }

    // Si no hay cache de hoy o menor, buscar la más reciente.
    final cache = await _cache.obtenerTasa();
    if (cache != null && _esTasaVigente(cache.fechaEfectiva)) {
      return cache;
    }

    if (cache != null) {
      final ultimaConsulta = await _cache.obtenerUltimaConsulta();
      if (ultimaConsulta != null) {
        final diff = DateTime.now().toUtc().difference(ultimaConsulta).inMinutes;
        if (diff < 30) return cache;
      }
    }

    return refrescarTasa();
  }

  Future<TasaBcv> refrescarTasa() async {
    await _cache.registrarConsulta();

    try {
      var tasa = await _api.obtenerTasa();
      tasa = await _aplicarHeuristicaFecha(tasa);
      await _cache.guardarTasa(tasa);
      // Si la tasa refrescada es de un día futuro, devolver la de hoy
      // (si existe). El usuario verá "Tasa siguiente disponible".
      return await _tasaActualPostRefresh(tasa);
    } catch (_) {
      final cache = await _cache.obtenerTasa();
      if (cache != null) return cache;
      var scrape = await _scraper.obtenerTasa();
      if (scrape != null) {
        scrape = await _aplicarHeuristicaFecha(scrape);
        await _cache.guardarTasa(scrape);
        return _tasaActualPostRefresh(scrape);
      }
      rethrow;
    }
  }

  /// Si [tasa] es de un día futuro (ej. ya salió la de mañana), buscar la de
  /// hoy en cache y devolverla. Si no, devolver [tasa] tal cual.
  Future<TasaBcv> _tasaActualPostRefresh(TasaBcv tasa) async {
    final ahora = ahoraVenezuela();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    final ef = DateTime(
      tasa.fechaEfectiva.year,
      tasa.fechaEfectiva.month,
      tasa.fechaEfectiva.day,
    );
    if (ef.isAfter(hoy)) {
      final cacheHoy = await _cache.obtenerTasaMasRecienteMenorQue(
          hoy.add(const Duration(days: 1)));
      if (cacheHoy != null) return cacheHoy;
    }
    return tasa;
  }

  Future<TasaBcv> _aplicarHeuristicaFecha(TasaBcv nuevaTasa) async {
    final ahora = ahoraVenezuela();
    if (ahora.hour < 14) return nuevaTasa;

    var cache = await _cache.obtenerTasa();
    
    // Si la app está recién instalada o sin caché, buscamos la tasa histórica de "hoy"
    if (cache == null) {
      final hoy = DateTime(ahora.year, ahora.month, ahora.day);
      try {
        cache = await _api.obtenerTasaHistorica(hoy);
      } catch (_) {}
    }

    if (cache == null) return nuevaTasa;

    // Si la tasa nueva es idéntica a la anterior, significa que BCV aún no ha
    // actualizado el valor para mañana. Mantenemos la fecha efectiva anterior (máximo hoy).
    final diffUsd = (nuevaTasa.usd - cache.usd).abs();
    if (diffUsd < 0.00001) {
      final hoy = DateTime(ahora.year, ahora.month, ahora.day);
      var ef = cache.fechaEfectiva;
      if (ef.isAfter(hoy)) ef = hoy;

      return TasaBcv(
        usd: nuevaTasa.usd,
        eur: nuevaTasa.eur,
        usdt: nuevaTasa.usdt,
        fecha: nuevaTasa.fecha,
        origen: nuevaTasa.origen,
        fechaEfectiva: ef,
      );
    }
    return nuevaTasa;
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

  /// Verifica si existe una tasa con fechaEfectiva posterior a hoy en cache.
  Future<bool> existeTasaSiguiente() async {
    final ahora = ahoraVenezuela();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    final cache = await _cache.obtenerTasa();
    if (cache == null) return false;
    return cache.fechaEfectiva.isAfter(hoy);
  }

  bool _esTasaVigente(DateTime fechaEfectiva) {
    final ahora = ahoraVenezuela();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);

    if (fechaEfectiva.isBefore(hoy)) return false;
    if (fechaEfectiva.isAfter(hoy)) return true;

    return ahora.hour < 14;
  }
}
