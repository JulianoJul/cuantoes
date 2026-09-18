import '../models/tasa_bcv.dart';
import '../utils/feriados_ve.dart';
import 'bcv_api_service.dart';
import 'bcv_cache_service.dart';
import 'bcv_scraper_service.dart';

class TasaRepository {
  final BcvApiService _api;
  final BcvScraperService _scraper;
  final BcvCacheService _cache;
  Future<TasaBcv>? _refreshEnCurso;

  TasaRepository({
    BcvApiService? api,
    BcvScraperService? scraper,
    BcvCacheService? cache,
  }) : _api = api ?? BcvApiService(),
       _scraper = scraper ?? BcvScraperService(),
       _cache = cache ?? BcvCacheService();

  Future<TasaBcv> obtenerTasa() async {
    final ahora = ahoraVenezuela();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);

    // Never use the latest cache entry blindly: it may be tomorrow's rate.
    final cacheActual = await _cache.obtenerTasaMasRecienteHasta(hoy);
    if (cacheActual != null && _esTasaVigente(cacheActual.fechaEfectiva)) {
      return cacheActual;
    }

    if (cacheActual != null) {
      final ultimaConsulta = await _cache.obtenerUltimaConsulta();
      if (ultimaConsulta != null) {
        final diff = DateTime.now().toUtc().difference(ultimaConsulta);
        if (diff >= Duration.zero && diff < const Duration(minutes: 30)) {
          return cacheActual;
        }
      }
    }

    return refrescarTasa();
  }

  Future<TasaBcv> refrescarTasa() async {
    final refreshActivo = _refreshEnCurso;
    if (refreshActivo != null) return refreshActivo;

    final refresh = _refrescarTasa();
    _refreshEnCurso = refresh;
    refresh.then<void>(
      (_) {
        if (identical(_refreshEnCurso, refresh)) _refreshEnCurso = null;
      },
      onError: (Object error) {
        if (identical(_refreshEnCurso, refresh)) _refreshEnCurso = null;
      },
    );
    return refresh;
  }

  Future<TasaBcv> _refrescarTasa() async {
    await _cache.registrarConsulta();

    try {
      var tasa = await _api.obtenerTasa();
      tasa = await _aplicarHeuristicaFecha(tasa);
      await _cache.guardarTasa(tasa);
      final actual = await _tasaActualPostRefresh(tasa);
      if (actual != null) return actual;
      throw StateError('La tasa obtenida aún no es efectiva hoy');
    } catch (error, stackTrace) {
      final cacheActual = await _cacheActual();
      if (cacheActual != null) return cacheActual;

      try {
        var scrape = await _scraper.obtenerTasa();
        if (scrape != null) {
          scrape = await _aplicarHeuristicaFecha(scrape);
          await _cache.guardarTasa(scrape);
          final actual = await _tasaActualPostRefresh(scrape);
          if (actual != null) return actual;
        }
      } catch (_) {
        // Preserve the original API error when the fallback also fails.
      }

      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  /// Selects the greatest effective entry that is not after today.
  Future<TasaBcv?> _tasaActualPostRefresh(TasaBcv tasa) async {
    final ahora = ahoraVenezuela();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    final cacheActual = await _cache.obtenerTasaMasRecienteHasta(hoy);
    final ef = _dia(tasa.fechaEfectiva);

    if (ef.isAfter(hoy)) return cacheActual;
    if (cacheActual == null) return tasa;

    return ef.isBefore(_dia(cacheActual.fechaEfectiva)) ? cacheActual : tasa;
  }

  Future<TasaBcv> _aplicarHeuristicaFecha(TasaBcv nuevaTasa) async {
    final ahora = ahoraVenezuela();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    var cache = await _cache.obtenerTasaMasRecienteHasta(hoy);

    // If a fresh install receives a future rate, recover today's last
    // effective rate so the future value is never shown as current.
    if (cache == null && _dia(nuevaTasa.fechaEfectiva).isAfter(hoy)) {
      try {
        final historica = await _api.obtenerTasaHistorica(hoy);
        if (historica != null && !_dia(historica.fechaEfectiva).isAfter(hoy)) {
          cache = historica;
          await _cache.guardarTasa(historica);
        }
      } catch (_) {
        // The realtime result can still be used if no historical result exists.
      }
    }

    if (cache == null) return nuevaTasa;

    // BCV's explicit Fecha Valor is authoritative even when the numeric
    // values happen to match the previous cached rate.
    if (nuevaTasa.origen == 'scraping_fecha_valor') return nuevaTasa;

    // If both values are unchanged, BCV has not published a new effective rate.
    // Keep the cached entry instead of rewriting today's key with future data.
    final diffUsd = (nuevaTasa.usd - cache.usd).abs();
    final diffEur = (nuevaTasa.eur - cache.eur).abs();
    if (diffUsd < 0.00001 &&
        diffEur < 0.00001 &&
        _dia(nuevaTasa.fechaEfectiva).isAfter(hoy)) {
      return cache;
    }
    return nuevaTasa;
  }

  Future<TasaBcv?> obtenerTasaHistorica(DateTime fecha) async {
    final ef = _dia(fecha);

    final cacheExacta = await _cache.obtenerTasaPorFecha(ef);
    if (cacheExacta != null) return cacheExacta;

    TasaBcv? desdeApi;
    try {
      final tasa = await _api.obtenerTasaHistorica(fecha);
      if (tasa != null && !_dia(tasa.fechaEfectiva).isAfter(ef)) {
        await _cache.guardarTasa(tasa);
        desdeApi = tasa;
      }
    } catch (_) {
      // If the historical API is unavailable, use only a prior cached rate.
    }

    // La API puede no tener la fecha efectiva más cercana (histórico
    // incompleto); la caché de tiempo real suele estar más completa.
    final cachePrevia = await _cache.obtenerTasaMasRecienteMenorQue(ef);
    if (desdeApi == null) return cachePrevia;
    if (cachePrevia == null) return desdeApi;

    return _dia(desdeApi.fechaEfectiva).isBefore(_dia(cachePrevia.fechaEfectiva))
        ? cachePrevia
        : desdeApi;
  }

  Future<TasaBcv?> obtenerTasaAnterior(DateTime fechaLimite) async {
    final limite = _dia(fechaLimite);
    final fechaAnterior = _diaHabilAnterior(limite);
    final cacheAnterior = await _cache.obtenerTasaPorFecha(fechaAnterior);
    if (cacheAnterior != null) return cacheAnterior;

    TasaBcv? desdeApi;
    try {
      final tasa = await _api.obtenerTasaAnterior(fechaLimite);
      if (tasa != null && _dia(tasa.fechaEfectiva).isBefore(limite)) {
        await _cache.guardarTasa(tasa);
        desdeApi = tasa;
      }
    } catch (_) {
      // Si la API falla, usamos la tasa cacheada más cercana anterior.
    }

    final cachePrevia = await _cache.obtenerTasaMasRecienteMenorQue(limite);
    if (desdeApi == null) return cachePrevia;
    if (cachePrevia == null) return desdeApi;

    return _dia(desdeApi.fechaEfectiva).isBefore(_dia(cachePrevia.fechaEfectiva))
        ? cachePrevia
        : desdeApi;
  }

  Future<double?> obtenerUsdt() async {
    try {
      return await _api.obtenerUsdt();
    } catch (_) {
      return null;
    }
  }

  /// Returns the closest cached future rate without making it current.
  Future<TasaBcv?> obtenerTasaSiguiente() async {
    final ahora = ahoraVenezuela();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    return _cache.obtenerTasaSiguiente(hoy);
  }

  /// Verifica si existe una tasa con fechaEfectiva posterior a hoy en cache.
  Future<bool> existeTasaSiguiente() async {
    return await obtenerTasaSiguiente() != null;
  }

  bool _esTasaVigente(DateTime fechaEfectiva) {
    final ahora = ahoraVenezuela();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    final efectiva = _dia(fechaEfectiva);

    if (efectiva.isAfter(hoy)) return false;
    if (efectiva.isBefore(hoy)) return _esDiaNoHabil(hoy);

    return _esDiaNoHabil(hoy) || ahora.hour < 14;
  }

  DateTime _diaHabilAnterior(DateTime fecha) {
    var anterior = DateTime(fecha.year, fecha.month, fecha.day - 1);
    while (_esDiaNoHabil(anterior)) {
      anterior = DateTime(anterior.year, anterior.month, anterior.day - 1);
    }
    return anterior;
  }

  bool _esDiaNoHabil(DateTime fecha) {
    final dia = _dia(fecha);
    return dia.weekday == DateTime.saturday ||
        dia.weekday == DateTime.sunday ||
        esFeriadoBancario(dia);
  }

  Future<TasaBcv?> _cacheActual() async {
    final ahora = ahoraVenezuela();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    return _cache.obtenerTasaMasRecienteHasta(hoy);
  }

  DateTime _dia(DateTime fecha) => DateTime(fecha.year, fecha.month, fecha.day);
}
