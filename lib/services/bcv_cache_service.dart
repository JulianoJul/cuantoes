import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/tasa_bcv.dart';
import '../utils/feriados_ve.dart';

class BcvCacheService {
  static const _keyPrefix = 'tasa_bcv_cache_';

  String _keyFecha(DateTime fecha) =>
      '$_keyPrefix${fecha.year}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}';

  DateTime _dia(DateTime fecha) => DateTime(fecha.year, fecha.month, fecha.day);

  bool _esFechaEfectivaLaboral(DateTime fecha) {
    final dia = _dia(fecha);
    return dia.weekday != DateTime.saturday &&
        dia.weekday != DateTime.sunday &&
        !esFeriadoBancario(dia);
  }

  Future<List<TasaBcv>> _obtenerTasas() async {
    final prefs = await SharedPreferences.getInstance();
    final tasas = <TasaBcv>[];

    for (final key in prefs.getKeys()) {
      if (!key.startsWith(_keyPrefix)) continue;
      final data = prefs.getString(key);
      if (data == null) continue;

      try {
        final json = jsonDecode(data) as Map<String, dynamic>;
        tasas.add(TasaBcv.fromJson(json));
      } on FormatException {
        // Ignore corrupted cache entries and keep usable rates available.
      } on TypeError {
        // Ignore cache entries with an obsolete or invalid shape.
      }
    }

    return tasas;
  }

  TasaBcv? _masReciente(Iterable<TasaBcv> tasas) {
    TasaBcv? mejor;
    for (final tasa in tasas) {
      if (mejor == null ||
          _dia(tasa.fechaEfectiva).isAfter(_dia(mejor.fechaEfectiva)) ||
          (_dia(tasa.fechaEfectiva) == _dia(mejor.fechaEfectiva) &&
              tasa.fecha.isAfter(mejor.fecha))) {
        mejor = tasa;
      }
    }
    return mejor;
  }

  Future<TasaBcv?> obtenerTasa() async {
    final ahora = ahoraVenezuela();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    return obtenerTasaMasRecienteHasta(hoy);
  }

  /// Returns the latest cached rate whose effective day is on or before
  /// [fechaLimite].
  Future<TasaBcv?> obtenerTasaMasRecienteHasta(DateTime fechaLimite) async {
    final limite = _dia(fechaLimite);
    final tasas = await _obtenerTasas();
    return _masReciente(
      tasas.where(
        (tasa) =>
            _esFechaEfectivaLaboral(tasa.fechaEfectiva) &&
            !_dia(tasa.fechaEfectiva).isAfter(limite),
      ),
    );
  }

  Future<TasaBcv?> obtenerTasaMasRecienteMenorQue(DateTime fechaLimite) async {
    final limite = _dia(fechaLimite);
    final tasas = await _obtenerTasas();
    return _masReciente(
      tasas.where(
        (tasa) =>
            _esFechaEfectivaLaboral(tasa.fechaEfectiva) &&
            _dia(tasa.fechaEfectiva).isBefore(limite),
      ),
    );
  }

  /// Returns the closest cached rate after [fechaBase].
  Future<TasaBcv?> obtenerTasaSiguiente(DateTime fechaBase) async {
    final base = _dia(fechaBase);
    TasaBcv? siguiente;

    for (final tasa in await _obtenerTasas()) {
      final efectiva = _dia(tasa.fechaEfectiva);
      if (!_esFechaEfectivaLaboral(efectiva) || !efectiva.isAfter(base)) {
        continue;
      }

      if (siguiente == null ||
          efectiva.isBefore(_dia(siguiente.fechaEfectiva)) ||
          (efectiva == _dia(siguiente.fechaEfectiva) &&
              tasa.fecha.isAfter(siguiente.fecha))) {
        siguiente = tasa;
      }
    }

    return siguiente;
  }

  Future<TasaBcv?> obtenerTasaPorFecha(DateTime fecha) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_keyFecha(fecha));
    if (data == null) return null;

    try {
      final json = jsonDecode(data) as Map<String, dynamic>;
      final tasa = TasaBcv.fromJson(json);
      return _esFechaEfectivaLaboral(tasa.fechaEfectiva) &&
              _dia(tasa.fechaEfectiva) == _dia(fecha)
          ? tasa
          : null;
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  Future<void> guardarTasa(TasaBcv tasa) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _keyFecha(tasa.fechaEfectiva),
      jsonEncode(tasa.toJson()),
    );
  }

  static const _keyUltimaConsulta = 'ultima_consulta_api';

  Future<DateTime?> obtenerUltimaConsulta() async {
    final prefs = await SharedPreferences.getInstance();
    final epoch = prefs.getInt(_keyUltimaConsulta);
    if (epoch == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(epoch, isUtc: true);
  }

  Future<void> registrarConsulta() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _keyUltimaConsulta,
      DateTime.now().toUtc().millisecondsSinceEpoch,
    );
  }
}
