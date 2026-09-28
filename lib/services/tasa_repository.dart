import '../models/cotizacion_usdt.dart';
import '../models/resultado_tasa.dart';
import '../models/tasa_bcv.dart';
import '../utils/feriados_ve.dart';
import 'bcv_api_service.dart';
import 'bcv_cache_service.dart';
import 'bcv_provider.dart';
import 'bcv_today_service.dart';
import 'chitty_bcv_service.dart';

class TasaRepository {
  static const _usdtTtl = Duration(hours: 1);
  static const _refreshCooldown = Duration(minutes: 30);

  final List<BcvProvider> _providers;
  final BcvCacheService _cache;
  Future<TasaBcv>? _refreshEnCurso;
  Future<CotizacionUsdt?>? _usdtEnCurso;
  ResultadoTasa? _ultimoResultado;

  TasaRepository({
    List<BcvProvider>? providers,
    BcvProvider? api,
    BcvCacheService? cache,
  }) : _providers =
           providers ??
           <BcvProvider>[
             api ?? DolarApiService(),
             if (api == null) BcvTodayService(),
             if (api == null) ChittyBcvService(),
           ],
       _cache = cache ?? BcvCacheService();

  Future<TasaBcv> obtenerTasa() async {
    final ahora = ahoraVenezuela();
    final hoy = _dia(ahora);
    final cacheActual = await _cache.obtenerTasaMasRecienteHasta(hoy);
    if (cacheActual != null && _esTasaVigente(cacheActual.fechaEfectiva)) {
      await _actualizarResultado(cacheActual, desdeCache: true);
      return cacheActual;
    }

    // A recent failed attempt should not trigger a network storm. A stale
    // cached quote can still be returned as an explicitly degraded fallback.
    if (cacheActual != null) {
      final ultimaConsulta = await _cache.obtenerUltimaConsulta();
      if (ultimaConsulta != null) {
        final diff = DateTime.now().toUtc().difference(ultimaConsulta);
        if (diff >= Duration.zero && diff < _refreshCooldown) {
          final validacion = await _cache.obtenerUltimaValidacionExitosa();
          final falloReciente =
              validacion == null || ultimaConsulta.isAfter(validacion);
          await _actualizarResultado(
            cacheActual,
            desdeCache: true,
            errorActualizacion: falloReciente
                ? 'No se pudo confirmar una actualización reciente'
                : null,
          );
          return cacheActual;
        }
      }
    }

    return refrescarTasa();
  }

  Future<ResultadoTasa> obtenerTasaConEstado() async {
    final tasa = await obtenerTasa();
    final resultado = _ultimoResultado;
    if (resultado != null) return resultado;
    return _crearResultado(tasa, desdeCache: false);
  }

  Future<TasaBcv> refrescarTasa() async {
    final activo = _refreshEnCurso;
    if (activo != null) return activo;

    final refresh = _refrescarTasa();
    _refreshEnCurso = refresh;
    refresh.then<void>(
      (_) {
        if (identical(_refreshEnCurso, refresh)) _refreshEnCurso = null;
      },
      onError: (Object _) {
        if (identical(_refreshEnCurso, refresh)) _refreshEnCurso = null;
      },
    );
    return refresh;
  }

  Future<ResultadoTasa> refrescarTasaConEstado() async {
    final tasa = await refrescarTasa();
    final resultado = _ultimoResultado;
    if (resultado != null) return resultado;
    return _crearResultado(tasa, desdeCache: false);
  }

  Future<TasaBcv> _refrescarTasa() async {
    // Cache persistence must not prevent network access.
    try {
      await _cache.registrarConsulta();
    } catch (_) {}

    final hoy = _dia(ahoraVenezuela());
    TasaBcv? mejorActual;
    var mejorActualDesdeRed = false;
    Object? primerError;
    StackTrace? primerStackTrace;

    for (final provider in _providers) {
      try {
        final recibida = await provider.obtenerTasa();
        if (!recibida.esValida) {
          throw FormatException(
            '${provider.nombre} devolvió valores inválidos',
          );
        }

        await _guardarSinBloquear(recibida);
        if (_dia(recibida.fechaEfectiva).isAfter(hoy)) {
          await _obtenerSiguiente(provider);
          final historica = await _historicaSegura(provider, hoy);
          final mejor = _mayorFecha(mejorActual, historica, hoy);
          if (identical(mejor, historica)) mejorActualDesdeRed = true;
          mejorActual = mejor;
          // A future realtime value does not satisfy a current-rate request.
          // Continue through the remaining providers before falling back.
          continue;
        }

        final mejor = _mayorFecha(mejorActual, recibida, hoy);
        if (identical(mejor, recibida)) mejorActualDesdeRed = true;
        mejorActual = mejor;
        await _obtenerSiguiente(provider);

        // Nothing can be newer than today's effective date without being a
        // future rate. Preserve the configured provider priority for this tie.
        if (_dia(recibida.fechaEfectiva).isAtSameMomentAs(hoy)) break;
      } catch (error, stackTrace) {
        primerError ??= error;
        primerStackTrace ??= stackTrace;
      }
    }

    final cacheActual = await _cacheActual();
    mejorActual = _mayorFecha(mejorActual, cacheActual, hoy);
    if (mejorActual != null) {
      final esRed = mejorActualDesdeRed && !identical(mejorActual, cacheActual);
      if (esRed) {
        try {
          await _cache.registrarValidacionExitosa();
        } catch (_) {}
      }
      await _actualizarResultado(
        mejorActual,
        desdeCache: !esRed,
        errorActualizacion: esRed ? null : primerError?.toString(),
      );
      return mejorActual;
    }

    if (primerError != null && primerStackTrace != null) {
      Error.throwWithStackTrace(primerError, primerStackTrace);
    }
    throw StateError('Ningún proveedor devolvió una tasa efectiva');
  }

  Future<void> _obtenerSiguiente(BcvProvider provider) async {
    try {
      final siguiente = await provider.obtenerTasaSiguiente();
      if (siguiente != null &&
          siguiente.esValida &&
          _dia(siguiente.fechaEfectiva).isAfter(_dia(ahoraVenezuela()))) {
        await _guardarSinBloquear(siguiente);
      }
    } catch (_) {
      // A missing optional next rate must not invalidate today's quote.
    }
  }

  Future<TasaBcv?> _historicaSegura(
    BcvProvider provider,
    DateTime fecha,
  ) async {
    try {
      final tasa = await provider.obtenerTasaHistorica(fecha);
      if (tasa == null ||
          !tasa.esValida ||
          _dia(tasa.fechaEfectiva).isAfter(fecha)) {
        return null;
      }
      await _guardarSinBloquear(tasa);
      return tasa;
    } catch (_) {
      return null;
    }
  }

  TasaBcv? _mayorFecha(TasaBcv? primera, TasaBcv? segunda, DateTime limite) {
    if (primera == null) return _esHasta(segunda, limite) ? segunda : null;
    if (segunda == null || !_esHasta(segunda, limite)) return primera;
    return _dia(segunda.fechaEfectiva).isAfter(_dia(primera.fechaEfectiva))
        ? segunda
        : primera;
  }

  bool _esHasta(TasaBcv? tasa, DateTime limite) =>
      tasa != null &&
      tasa.esValida &&
      !_dia(tasa.fechaEfectiva).isAfter(_dia(limite));

  Future<void> _guardarSinBloquear(TasaBcv tasa) async {
    try {
      await _cache.guardarTasa(tasa);
    } catch (_) {
      // A valid network result remains usable if local storage is unavailable.
    }
  }

  Future<TasaBcv?> obtenerTasaHistorica(DateTime fecha) async {
    final limite = _dia(fecha);
    final cacheExacta = await _cache.obtenerTasaPorFecha(limite);
    if (cacheExacta != null) return cacheExacta;

    TasaBcv? mejor;
    for (final provider in _providers) {
      try {
        final tasa = await provider.obtenerTasaHistorica(limite);
        if (tasa == null || !tasa.esValida || !_esHasta(tasa, limite)) continue;
        await _guardarSinBloquear(tasa);
        mejor = _mayorFecha(mejor, tasa, limite);
        if (_dia(tasa.fechaEfectiva).isAtSameMomentAs(limite)) break;
      } catch (_) {
        // Continue through providers; a sparse earlier result is not final.
      }
    }

    final cachePrevia = await _cache.obtenerTasaMasRecienteHasta(limite);
    return _mayorFecha(mejor, cachePrevia, limite);
  }

  Future<TasaBcv?> obtenerTasaAnterior(DateTime fechaLimite) async {
    final limite = _dia(fechaLimite);
    final cacheAnterior = await _cache.obtenerTasaMasRecienteMenorQue(limite);
    final diaHabilPrevio = _diaHabilAnterior(limite);
    if (cacheAnterior != null &&
        _dia(cacheAnterior.fechaEfectiva).isAtSameMomentAs(diaHabilPrevio)) {
      return cacheAnterior;
    }

    TasaBcv? mejor = cacheAnterior;
    for (final provider in _providers) {
      try {
        final tasa = await provider.obtenerTasaAnterior(limite);
        if (tasa == null ||
            !tasa.esValida ||
            !_dia(tasa.fechaEfectiva).isBefore(limite)) {
          continue;
        }
        await _guardarSinBloquear(tasa);
        mejor = _mayorFecha(
          mejor,
          tasa,
          limite.subtract(const Duration(days: 1)),
        );
      } catch (_) {
        // A failed history source does not prevent use of the cache.
      }
    }
    return mejor;
  }

  Future<CotizacionUsdt?> obtenerCotizacionUsdt({bool forzar = false}) async {
    final activo = _usdtEnCurso;
    if (activo != null) return activo;

    final cache = await _cache.obtenerCotizacionUsdt();
    final ahora = DateTime.now().toUtc();
    if (!forzar && cache != null) {
      final antiguedad = ahora.difference(cache.obtenidaEnUtc);
      if (antiguedad >= Duration.zero && antiguedad < _usdtTtl) return cache;
    }

    final request = _obtenerCotizacionUsdt(cache);
    _usdtEnCurso = request;
    request.then<void>(
      (_) {
        if (identical(_usdtEnCurso, request)) _usdtEnCurso = null;
      },
      onError: (Object _) {
        if (identical(_usdtEnCurso, request)) _usdtEnCurso = null;
      },
    );
    return request;
  }

  Future<CotizacionUsdt?> _obtenerCotizacionUsdt(CotizacionUsdt? cache) async {
    for (final provider in _providers) {
      try {
        final quote = await provider.obtenerCotizacionUsdt();
        if (quote == null || !quote.esValida) continue;
        try {
          await _cache.guardarCotizacionUsdt(quote);
        } catch (_) {}
        return quote;
      } catch (_) {
        // Try the next source and preserve the last persisted P2P quote.
      }
    }
    return cache;
  }

  Future<double?> obtenerUsdt() async => (await obtenerCotizacionUsdt())?.valor;

  Future<TasaBcv?> obtenerTasaSiguiente() async {
    final ahora = ahoraVenezuela();
    final hoy = _dia(ahora);
    final siguienteCache = await _cache.obtenerTasaSiguiente(hoy);
    if (siguienteCache != null) return siguienteCache;

    for (final provider in _providers) {
      try {
        final siguiente = await provider.obtenerTasaSiguiente();
        if (siguiente == null ||
            !siguiente.esValida ||
            !_dia(siguiente.fechaEfectiva).isAfter(hoy)) {
          continue;
        }
        await _guardarSinBloquear(siguiente);
        return siguiente;
      } catch (_) {}
    }
    return null;
  }

  Future<bool> existeTasaSiguiente() async =>
      await obtenerTasaSiguiente() != null;

  bool _esTasaVigente(DateTime fechaEfectiva) {
    final hoy = _dia(ahoraVenezuela());
    return _dia(fechaEfectiva).isAtSameMomentAs(_ultimaFechaHabil(hoy));
  }

  DateTime _ultimaFechaHabil(DateTime hoy) {
    var dia = _dia(hoy);
    while (_esDiaNoHabil(dia)) {
      dia = dia.subtract(const Duration(days: 1));
    }
    return dia;
  }

  DateTime _diaHabilAnterior(DateTime fecha) =>
      _ultimaFechaHabil(_dia(fecha).subtract(const Duration(days: 1)));

  bool _esDiaNoHabil(DateTime fecha) {
    final dia = _dia(fecha);
    return dia.weekday == DateTime.saturday ||
        dia.weekday == DateTime.sunday ||
        esFeriadoBancario(dia);
  }

  Future<TasaBcv?> _cacheActual() async {
    final hoy = _dia(ahoraVenezuela());
    return _cache.obtenerTasaMasRecienteHasta(hoy);
  }

  Future<void> _actualizarResultado(
    TasaBcv tasa, {
    required bool desdeCache,
    String? errorActualizacion,
  }) async {
    _ultimoResultado = await _crearResultado(
      tasa,
      desdeCache: desdeCache,
      errorActualizacion: errorActualizacion,
    );
  }

  Future<ResultadoTasa> _crearResultado(
    TasaBcv tasa, {
    required bool desdeCache,
    String? errorActualizacion,
  }) async {
    DateTime? ultimaValidacion;
    DateTime? ultimoIntento;
    try {
      ultimaValidacion = await _cache.obtenerUltimaValidacionExitosa();
      ultimoIntento = await _cache.obtenerUltimaConsulta();
    } catch (_) {}
    final estado = _esTasaVigente(tasa.fechaEfectiva)
        ? EstadoFrescuraTasa.vigente
        : EstadoFrescuraTasa.antigua;
    return ResultadoTasa(
      tasa: tasa,
      modoObtencion: desdeCache
          ? ModoObtencionTasa.cache
          : ModoObtencionTasa.red,
      ultimaValidacionExitosaUtc: ultimaValidacion,
      ultimoIntentoUtc: ultimoIntento,
      frescura: estado,
      errorActualizacion: errorActualizacion,
    );
  }

  DateTime _dia(DateTime fecha) => DateTime(fecha.year, fecha.month, fecha.day);
}
