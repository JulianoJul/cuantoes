import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/tasa_bcv.dart';
import '../models/cotizacion_usdt.dart';
import '../utils/feriados_ve.dart';
import 'bcv_provider.dart';

/// Cliente de DolarAPI, la fuente primaria de tasas oficiales BCV.
class DolarApiService implements BcvProvider {
  static const _baseUrl = 'https://ve.dolarapi.com/v1';
  static const _timeout = Duration(seconds: 10);

  final http.Client _client;

  DolarApiService({http.Client? client}) : _client = client ?? http.Client();

  @override
  String get nombre => 'DolarAPI';

  @override
  Future<TasaBcv> obtenerTasa() async {
    final respuestas = await Future.wait([
      _obtenerMapa(Uri.parse('$_baseUrl/dolares/oficial')),
      _obtenerMapa(Uri.parse('$_baseUrl/euros/oficial')),
    ]);

    final usd = _parsearCotizacion(respuestas[0], 'USD');
    final eur = _parsearCotizacion(respuestas[1], 'EUR');

    if (!_mismoDia(usd.fechaEfectiva, eur.fechaEfectiva)) {
      throw StateError('DolarAPI devolvió USD y EUR de fechas distintas');
    }

    return TasaBcv(
      usd: usd.valor,
      eur: eur.valor,
      usdt: 0,
      fecha: usd.fecha,
      origen: 'dolarapi',
      fechaEfectiva: usd.fechaEfectiva,
      fechaEfectivaExplicita: false,
    );
  }

  @override
  Future<TasaBcv?> obtenerTasaHistorica(DateTime fecha) async {
    return _obtenerHistoricoComun(fecha, incluirLimite: true);
  }

  @override
  Future<TasaBcv?> obtenerTasaAnterior(DateTime fechaLimite) async {
    return _obtenerHistoricoComun(fechaLimite, incluirLimite: false);
  }

  @override
  Future<TasaBcv?> obtenerTasaSiguiente() async {
    final respuestas = await Future.wait([
      _obtenerLista(Uri.parse('$_baseUrl/historicos/dolares/oficial')),
      _obtenerLista(Uri.parse('$_baseUrl/historicos/euros/oficial')),
    ]);
    final usd = _agruparHistorico(respuestas[0], 'USD');
    final eur = _agruparHistorico(respuestas[1], 'EUR');
    final ahora = ahoraVenezuela();
    final hoy = _dia(ahora);
    final fechas =
        usd.keys
            .where((fecha) => eur.containsKey(fecha) && fecha.isAfter(hoy))
            .toList()
          ..sort();
    if (fechas.isEmpty) return null;
    final fecha = fechas.first;
    final usdQuote = usd[fecha]!;
    final eurQuote = eur[fecha]!;
    return TasaBcv(
      usd: usdQuote.valor,
      eur: eurQuote.valor,
      usdt: 0,
      fecha: usdQuote.fecha,
      origen: 'dolarapi',
      fechaEfectiva: fecha,
      fechaEfectivaExplicita: true,
    );
  }

  @override
  Future<double?> obtenerUsdt() async => null;

  @override
  Future<CotizacionUsdt?> obtenerCotizacionUsdt() async => null;

  Future<TasaBcv?> _obtenerHistoricoComun(
    DateTime fechaLimite, {
    required bool incluirLimite,
  }) async {
    final respuestas = await Future.wait([
      _obtenerLista(Uri.parse('$_baseUrl/historicos/dolares/oficial')),
      _obtenerLista(Uri.parse('$_baseUrl/historicos/euros/oficial')),
    ]);

    final usdPorFecha = _agruparHistorico(respuestas[0], 'USD');
    final eurPorFecha = _agruparHistorico(respuestas[1], 'EUR');
    final limite = _dia(fechaLimite);
    DateTime? mejorFecha;

    for (final fecha in usdPorFecha.keys) {
      if (!eurPorFecha.containsKey(fecha)) continue;
      final permitida = incluirLimite
          ? !fecha.isAfter(limite)
          : fecha.isBefore(limite);
      if (!permitida) continue;
      if (mejorFecha == null || fecha.isAfter(mejorFecha)) {
        mejorFecha = fecha;
      }
    }

    if (mejorFecha == null) return null;
    final usd = usdPorFecha[mejorFecha]!;
    final eur = eurPorFecha[mejorFecha]!;

    return TasaBcv(
      usd: usd.valor,
      eur: eur.valor,
      usdt: 0,
      fecha: usd.fecha,
      origen: 'dolarapi',
      fechaEfectiva: mejorFecha,
      fechaEfectivaExplicita: true,
    );
  }

  Future<Map<String, dynamic>> _obtenerMapa(Uri uri) async {
    final decoded = await _obtenerJson(uri);
    if (decoded is! Map) {
      throw FormatException('$nombre devolvió un objeto inválido');
    }
    return Map<String, dynamic>.from(decoded);
  }

  Future<List<dynamic>> _obtenerLista(Uri uri) async {
    final decoded = await _obtenerJson(uri);
    if (decoded is! List) {
      throw FormatException('$nombre devolvió un histórico inválido');
    }
    return decoded;
  }

  Future<dynamic> _obtenerJson(Uri uri) async {
    final response = await _client
        .get(
          uri,
          headers: const {
            'Accept': 'application/json',
            'Cache-Control': 'no-cache',
          },
        )
        .timeout(_timeout);

    if (response.statusCode != 200) {
      throw StateError('$nombre: HTTP ${response.statusCode}');
    }

    try {
      return jsonDecode(response.body);
    } on FormatException catch (error) {
      throw FormatException('$nombre devolvió JSON inválido: $error');
    }
  }

  _ApiQuote _parsearCotizacion(Map<String, dynamic> map, String moneda) {
    final valor = map['promedio'];
    final rawFecha = map['fechaActualizacion'] ?? map['fecha'];
    if (valor is! num || rawFecha is! String) {
      throw FormatException('$nombre no devolvió una tasa $moneda válida');
    }

    final fecha = _parsearFecha(rawFecha);
    if (fecha == null || valor <= 0) {
      throw FormatException('$nombre no devolvió una tasa $moneda válida');
    }

    return _ApiQuote(
      valor: valor.toDouble(),
      fecha: fecha,
      fechaEfectiva: _fechaCivilVenezuela(rawFecha, fecha),
    );
  }

  Map<DateTime, _ApiQuote> _agruparHistorico(
    List<dynamic> entries,
    String moneda,
  ) {
    final result = <DateTime, _ApiQuote>{};

    for (final entry in entries) {
      if (entry is! Map) continue;
      final map = Map<String, dynamic>.from(entry);
      final valor = map['promedio'];
      final rawFecha = map['fecha'];
      if (valor is! num || rawFecha is! String || valor <= 0) continue;

      final fecha = _parsearFecha(rawFecha);
      if (fecha == null) continue;
      final quote = _ApiQuote(
        valor: valor.toDouble(),
        fecha: fecha,
        fechaEfectiva: _fechaCivilVenezuela(rawFecha, fecha),
      );
      final previous = result[quote.fechaEfectiva];
      if (previous == null || quote.fecha.isAfter(previous.fecha)) {
        result[quote.fechaEfectiva] = quote;
      }
    }

    if (result.isEmpty) {
      throw FormatException('$nombre no devolvió histórico de $moneda');
    }
    return result;
  }

  bool _mismoDia(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;

  DateTime _dia(DateTime fecha) => DateTime(fecha.year, fecha.month, fecha.day);

  DateTime _fechaCivilVenezuela(String raw, DateTime parsed) {
    // Date-only values are civil dates, not UTC instants. Preserve their day.
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(raw)) {
      return DateTime(parsed.year, parsed.month, parsed.day);
    }
    final hasZone = RegExp(
      r'(Z|[+-]\d{2}:?\d{2})$',
      caseSensitive: false,
    ).hasMatch(raw);
    final instante = hasZone
        ? parsed.toUtc()
        : DateTime.utc(
            parsed.year,
            parsed.month,
            parsed.day,
            parsed.hour,
            parsed.minute,
            parsed.second,
            parsed.millisecond,
            parsed.microsecond,
          );
    final venezuela = instante.subtract(const Duration(hours: 4));
    return DateTime(venezuela.year, venezuela.month, venezuela.day);
  }

  DateTime? _parsearFecha(String raw) {
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(raw)) {
      return DateTime.tryParse(raw);
    }
    final fecha = DateTime.tryParse(raw);
    if (fecha == null) return null;
    final tieneZona = RegExp(
      r'(Z|[+-]\d{2}:?\d{2})$',
      caseSensitive: false,
    ).hasMatch(raw);
    if (tieneZona) return fecha;

    // The API contract treats zone-less timestamps as UTC, not device local.
    return DateTime.utc(
      fecha.year,
      fecha.month,
      fecha.day,
      fecha.hour,
      fecha.minute,
      fecha.second,
      fecha.millisecond,
      fecha.microsecond,
    );
  }
}

/// Nombre anterior conservado para no romper integraciones internas.
/// La implementación ahora consulta DolarAPI.
class BcvApiService extends DolarApiService {
  BcvApiService({super.client});
}

class _ApiQuote {
  final double valor;
  final DateTime fecha;
  final DateTime fechaEfectiva;

  const _ApiQuote({
    required this.valor,
    required this.fecha,
    required this.fechaEfectiva,
  });
}
