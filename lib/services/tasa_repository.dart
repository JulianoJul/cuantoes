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
    final cache = await _cache.obtenerTasa();
    if (cache != null && _esTasaVigente(cache.fechaEfectiva)) {
      return cache;
    }

    if (cache != null) {
      final ultimaConsulta = await _cache.obtenerUltimaConsulta();
      if (ultimaConsulta != null) {
        final ahora = DateTime.now().toUtc();
        final diff = ahora.difference(ultimaConsulta).inMinutes;
        if (diff < 30) {
          // Cooldown activo (esperar 30 min entre consultas automáticas)
          return cache;
        }
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
      return tasa;
    } catch (_) {
      final cache = await _cache.obtenerTasa();
      if (cache != null) return cache;
      var scrape = await _scraper.obtenerTasa();
      if (scrape != null) {
        scrape = await _aplicarHeuristicaFecha(scrape);
        await _cache.guardarTasa(scrape);
        return scrape;
      }
      rethrow;
    }
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

  bool _esTasaVigente(DateTime fechaEfectiva) {
    final ahora = ahoraVenezuela();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);

    if (fechaEfectiva.isBefore(hoy)) return false;
    if (fechaEfectiva.isAfter(hoy)) return true;

    return ahora.hour < 14;
  }
}
