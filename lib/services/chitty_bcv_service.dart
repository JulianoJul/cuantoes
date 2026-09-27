import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/tasa_bcv.dart';
import '../utils/feriados_ve.dart';
import 'bcv_provider.dart';

/// Cliente del dataset estático de Chitty BCV.
///
/// Es el tercer fallback para la tasa actual. Su histórico público es de IPC,
/// no un histórico diario USD/EUR, por eso no se usa para fechas anteriores.
class ChittyBcvService implements BcvProvider {
  static const _latestUrl =
      'https://chitty400.github.io/chitty-bcv-api/latest.json';
  static const _p2pHistoryUrl =
      'https://chitty400.github.io/chitty-bcv-api/p2p_history.json';
  static const _timeout = Duration(seconds: 10);
  static const _venezuelaOffset = Duration(hours: 4);

  final http.Client _client;

  ChittyBcvService({http.Client? client}) : _client = client ?? http.Client();

  @override
  String get nombre => 'Chitty BCV';

  @override
  Future<TasaBcv> obtenerTasa() async {
    final map = await _obtenerMapa(Uri.parse(_latestUrl));
    final tasas = map['tasas'];
    final tasasMap = tasas is Map
        ? Map<String, dynamic>.from(tasas)
        : const <String, dynamic>{};
    final usd = _numero(tasasMap['usd']) ?? _numero(map['tasa_bcv']);
    final eur = _numero(tasasMap['eur']);
    if (usd == null || eur == null || usd <= 0 || eur <= 0) {
      throw FormatException('$nombre no devolvió USD y EUR válidos');
    }

    final fechaActualizacion = _fecha(map['updated_at']) ?? DateTime.now();
    final fechaEfectiva = _fecha(map['effective_date']) ??
        _fecha(map['fecha']) ??
        _ultimoDiaHabil(_enVenezuela(fechaActualizacion));

    return TasaBcv(
      usd: usd,
      eur: eur,
      usdt: 0,
      fecha: fechaActualizacion,
      origen: 'chitty_bcv',
      fechaEfectiva: _dia(fechaEfectiva),
    );
  }

  @override
  Future<TasaBcv?> obtenerTasaHistorica(DateTime fecha) async => null;

  @override
  Future<TasaBcv?> obtenerTasaAnterior(DateTime fechaLimite) async => null;

  @override
  Future<double?> obtenerUsdt() async {
    final decoded = await _obtenerJson(Uri.parse(_p2pHistoryUrl));
    if (decoded is! Map) return null;

    final hoy = _dia(ahoraVenezuela());
    DateTime? fechaElegida;
    double? tasaElegida;

    for (final entry in decoded.entries) {
      final fecha = DateTime.tryParse(entry.key.toString());
      if (fecha == null || _dia(fecha).isAfter(hoy) || entry.value is! Map) {
        continue;
      }

      final dia = Map<String, dynamic>.from(entry.value as Map);
      final ves = dia['ves'];
      if (ves is! Map) continue;
      final vesMap = Map<String, dynamic>.from(ves);
      final valor = _numero(vesMap['tasa_final_promedio']);
      if (valor == null || valor <= 0) continue;

      if (fechaElegida == null || fecha.isAfter(fechaElegida)) {
        fechaElegida = fecha;
        tasaElegida = valor;
      }
    }

    return tasaElegida;
  }

  Future<Map<String, dynamic>> _obtenerMapa(Uri uri) async {
    final decoded = await _obtenerJson(uri);
    if (decoded is! Map) {
      throw FormatException('$nombre devolvió un objeto inválido');
    }
    return Map<String, dynamic>.from(decoded);
  }

  Future<dynamic> _obtenerJson(Uri uri) async {
    final response = await _client
        .get(uri, headers: _headers)
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

  double? _numero(dynamic value) => value is num ? value.toDouble() : null;

  DateTime? _fecha(dynamic value) =>
      value is String ? DateTime.tryParse(value) : null;

  DateTime _enVenezuela(DateTime fecha) =>
      fecha.toUtc().subtract(_venezuelaOffset);

  DateTime _ultimoDiaHabil(DateTime fecha) {
    var dia = _dia(fecha);
    while (dia.weekday == DateTime.saturday ||
        dia.weekday == DateTime.sunday ||
        esFeriadoBancario(dia)) {
      dia = dia.subtract(const Duration(days: 1));
    }
    return dia;
  }

  DateTime _dia(DateTime fecha) => DateTime(fecha.year, fecha.month, fecha.day);

  static const _headers = {
    'Accept': 'application/json',
    'Cache-Control': 'no-cache',
  };
}
