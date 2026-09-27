import '../models/tasa_bcv.dart';
import '../utils/feriados_ve.dart';
import 'bcv_api_service.dart';
import 'bcv_cache_service.dart';
import 'bcv_provider.dart';
import 'bcv_today_service.dart';
import 'chitty_bcv_service.dart';

class TasaRepository {
  final List<BcvProvider> _providers;
  final BcvCacheService _cache;
  Future<TasaBcv>? _refreshEnCurso;

  TasaRepository({
    List<BcvProvider>? providers,
    BcvProvider? api,
    BcvCacheService? cache,
  }) : _providers = providers ?? <BcvProvider>[
         api ?? DolarApiService(),
         if (api == null) BcvTodayService(),
         if (api == null) ChittyBcvService(),
       ],
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

    Object? primerError;
    StackTrace? primerStackTrace;

    for (final provider in _providers) {
      try {
        var tasa = await provider.obtenerTasa();
        tasa = await _aplicarHeuristicaFecha(tasa, provider);
        await _cache.guardarTasa(tasa);
        final actual = await _tasaActualPostRefresh(tasa);
        if (actual != null) return actual;
      } catch (error, stackTrace) {
        primerError ??= error;
        primerStackTrace ??= stackTrace;
      }
    }

    final cacheActual = await _cacheActual();
    if (cacheActual != null) return cacheActual;

    if (primerError != null && primerStackTrace != null) {
      Error.throwWithStackTrace(primerError, primerStackTrace);
    }

    throw StateError('Ningún proveedor devolvió una tasa efectiva');
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

  Future<TasaBcv> _aplicarHeuristicaFecha(
    TasaBcv nuevaTasa,
    BcvProvider provider,
  ) async {
    final ahora = ahoraVenezuela();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    var cache = await _cache.obtenerTasaMasRecienteHasta(hoy);

    // If a fresh install receives a future rate, recover today's last
    // effective rate so the future value is never shown as current.
    if (cache == null && _dia(nuevaTasa.fechaEfectiva).isAfter(hoy)) {
      try {
        final historica = await provider.obtenerTasaHistorica(hoy);
        if (historica != null && !_dia(historica.fechaEfectiva).isAfter(hoy)) {
          cache = historica;
          await _cache.guardarTasa(historica);
        }
      } catch (_) {
        // The realtime result can still be used if no historical result exists.
      }
    }

    if (cache == null) return nuevaTasa;

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

    TasaBcv? desdeProveedor;
    for (final provider in _providers) {
      try {
        final tasa = await provider.obtenerTasaHistorica(fecha);
        if (tasa != null && !_dia(tasa.fechaEfectiva).isAfter(ef)) {
          await _cache.guardarTasa(tasa);
          desdeProveedor = tasa;
          break;
        }
      } catch (_) {
        // Prueba el siguiente proveedor.
      }
    }

    // La API puede no tener la fecha efectiva más cercana (histórico
    // incompleto); la caché de tiempo real suele estar más completa.
    final cachePrevia = await _cache.obtenerTasaMasRecienteMenorQue(ef);
    if (desdeProveedor == null) return cachePrevia;
    if (cachePrevia == null) return desdeProveedor;

    return _dia(desdeProveedor.fechaEfectiva).isBefore(
          _dia(cachePrevia.fechaEfectiva),
        )
        ? cachePrevia
        : desdeProveedor;
  }

  Future<TasaBcv?> obtenerTasaAnterior(DateTime fechaLimite) async {
    final limite = _dia(fechaLimite);
    final fechaAnterior = _diaHabilAnterior(limite);
    final cacheAnterior = await _cache.obtenerTasaPorFecha(fechaAnterior);
    if (cacheAnterior != null) return cacheAnterior;

    TasaBcv? desdeProveedor;
    for (final provider in _providers) {
      try {
        final tasa = await provider.obtenerTasaAnterior(fechaLimite);
        if (tasa != null && _dia(tasa.fechaEfectiva).isBefore(limite)) {
          await _cache.guardarTasa(tasa);
          desdeProveedor = tasa;
          break;
        }
      } catch (_) {
        // Prueba el siguiente proveedor.
      }
    }

    final cachePrevia = await _cache.obtenerTasaMasRecienteMenorQue(limite);
    if (desdeProveedor == null) return cachePrevia;
    if (cachePrevia == null) return desdeProveedor;

    return _dia(desdeProveedor.fechaEfectiva).isBefore(
          _dia(cachePrevia.fechaEfectiva),
        )
        ? cachePrevia
        : desdeProveedor;
  }

  Future<double?> obtenerUsdt() async {
    for (final provider in _providers) {
      try {
        final usdt = await provider.obtenerUsdt();
        if (usdt != null && usdt > 0) return usdt;
      } catch (_) {
        // Prueba el siguiente proveedor.
      }
    }
    return null;
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
