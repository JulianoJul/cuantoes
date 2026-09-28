import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/tasa_bcv.dart';
import '../models/cotizacion_usdt.dart';
import 'bcv_provider.dart';

/// Cliente de BCV Today, una API estática servida por GitHub Pages/CDN.
class BcvTodayService implements BcvProvider {
  static const _baseUrl = 'https://bcv.today/api/v1';
  static const _timeout = Duration(seconds: 10);
  static const _maxHistoricalLookbackDays = 31;

  final http.Client _client;

  BcvTodayService({http.Client? client}) : _client = client ?? http.Client();

  @override
  String get nombre => 'BCV Today';

  @override
  Future<TasaBcv> obtenerTasa() async {
    final map = await _obtenerMapa(Uri.parse('$_baseUrl/rate.json'));
    return _crearTasa(map);
  }

  @override
  Future<TasaBcv?> obtenerTasaHistorica(DateTime fecha) async {
    return _buscarSnapshot(fecha, limite: _dia(fecha));
  }

  @override
  Future<TasaBcv?> obtenerTasaAnterior(DateTime fechaLimite) async {
    final limite = _dia(fechaLimite);
    final inicio = limite.subtract(const Duration(days: 1));
    return _buscarSnapshot(
      inicio,
      limite: limite.subtract(const Duration(days: 1)),
    );
  }

  @override
  Future<double?> obtenerUsdt() async => null;

  @override
  Future<TasaBcv?> obtenerTasaSiguiente() async => null;

  @override
  Future<CotizacionUsdt?> obtenerCotizacionUsdt() async => null;

  Future<TasaBcv?> _buscarSnapshot(
    DateTime fechaInicio, {
    required DateTime limite,
  }) async {
    var fecha = _dia(fechaInicio);

    for (var intento = 0; intento <= _maxHistoricalLookbackDays; intento++) {
      final map = await _obtenerMapaOpcional(
        Uri.parse('$_baseUrl/history/${_formatearFecha(fecha)}.json'),
      );
      if (map != null) {
        try {
          final tasa = _crearTasa(map);
          if (!_dia(tasa.fechaEfectiva).isAfter(_dia(limite))) {
            return tasa;
          }
        } on FormatException {
          // Un snapshot incompleto no debe impedir probar el día anterior.
        }
      }
      fecha = fecha.subtract(const Duration(days: 1));
    }

    return null;
  }

  TasaBcv _crearTasa(Map<String, dynamic> map) {
    final usd = _numero(map, const ['USD', 'usd']);
    final eur = _numero(map, const ['EUR', 'eur']);
    if (usd == null || eur == null || usd <= 0 || eur <= 0) {
      throw FormatException('$nombre no devolvió USD y EUR válidos');
    }

    final fechaEfectiva = _fecha(map['effective_date']) ?? _fecha(map['date']);
    final fecha = _fecha(map['updated_at']) ?? fechaEfectiva;
    if (fechaEfectiva == null || fecha == null) {
      throw FormatException('$nombre no devolvió una fecha válida');
    }

    return TasaBcv(
      usd: usd,
      eur: eur,
      usdt: 0,
      fecha: fecha,
      origen: 'bcv_today',
      fechaEfectiva: _dia(fechaEfectiva),
      fechaEfectivaExplicita: map['effective_date'] != null,
    );
  }

  Future<Map<String, dynamic>> _obtenerMapa(Uri uri) async {
    final response = await _client
        .get(uri, headers: _headers)
        .timeout(_timeout);
    if (response.statusCode != 200) {
      throw StateError('$nombre: HTTP ${response.statusCode}');
    }
    return _decodificarMapa(response.body);
  }

  Future<Map<String, dynamic>?> _obtenerMapaOpcional(Uri uri) async {
    final response = await _client
        .get(uri, headers: _headers)
        .timeout(_timeout);
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw StateError('$nombre: HTTP ${response.statusCode}');
    }
    return _decodificarMapa(response.body);
  }

  Map<String, dynamic> _decodificarMapa(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map) {
        throw FormatException('$nombre devolvió un objeto inválido');
      }
      return Map<String, dynamic>.from(decoded);
    } on FormatException {
      rethrow;
    } catch (error) {
      throw FormatException('$nombre devolvió JSON inválido: $error');
    }
  }

  double? _numero(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is num) return value.toDouble();
    }
    return null;
  }

  DateTime? _fecha(dynamic raw) {
    if (raw is! String) return null;
    return DateTime.tryParse(raw);
  }

  String _formatearFecha(DateTime fecha) =>
      '${fecha.year}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}';

  DateTime _dia(DateTime fecha) => DateTime(fecha.year, fecha.month, fecha.day);

  static const _headers = {
    'Accept': 'application/json',
    'Cache-Control': 'no-cache',
  };
}
