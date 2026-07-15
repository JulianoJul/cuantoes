import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/tasa_bcv.dart';
import '../utils/feriados_ve.dart';

class BcvApiService {
  static const _baseUrl = 'https://dolar-vzla.rafnixg.dev/api/v1';

  Future<TasaBcv> obtenerTasa() async {
    final response = await http
        .get(Uri.parse('$_baseUrl/bcv/realtime'))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('Error en API BCV: HTTP ${response.statusCode}');
    }

    final List<dynamic> data = json.decode(response.body) as List<dynamic>;

    double? usd;
    double? eur;
    DateTime? fecha;

    for (final entry in data) {
      final map = entry as Map<String, dynamic>;
      final currency = map['currency'] as String;
      final rate = (map['rate'] as num).toDouble();
      final dateStr = map['date'] as String;

      if (currency == 'dolar') usd = rate;
      if (currency == 'euro') eur = rate;
      fecha ??= DateTime.parse(dateStr);
    }

    if (usd == null || eur == null) {
      throw Exception('API no devolvió USD y EUR');
    }

    return TasaBcv.actual(
      usd: usd,
      eur: eur,
      usdt: 0,
      fecha: fecha ?? DateTime.now(),
      origen: 'api',
    );
  }

  Future<double> obtenerUsdt() async {
    final response = await http
        .get(Uri.parse('$_baseUrl/binance/realtime_ves'))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('Error al obtener USDT: HTTP ${response.statusCode}');
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    return (data['median_price'] as num?)?.toDouble() ?? 0;
  }

  Future<TasaBcv?> obtenerTasaAnterior(DateTime fechaLimite) async {
    final limite = DateTime(
      fechaLimite.year,
      fechaLimite.month,
      fechaLimite.day,
    );

    String formatDate(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}T00:00:00';

    final inicio = formatDate(limite.subtract(const Duration(days: 30)));
    final fin = formatDate(limite.subtract(const Duration(days: 1)));

    final results = await Future.wait([
      http
          .get(Uri.parse(
              '$_baseUrl/history/bcv?currency=dolar&start_date=$inicio&end_date=$fin&limit=50&order=desc'))
          .timeout(const Duration(seconds: 10)),
      http
          .get(Uri.parse(
              '$_baseUrl/history/bcv?currency=euro&start_date=$inicio&end_date=$fin&limit=50&order=desc'))
          .timeout(const Duration(seconds: 10)),
    ]);

    List<Map<String, dynamic>> extraerRates(http.Response response) {
      if (response.statusCode != 200) return [];
      final body = json.decode(response.body) as Map<String, dynamic>;
      final currencies = body['currencies'] as List<dynamic>? ?? [];
      return currencies.cast<Map<String, dynamic>>();
    }

    final dolarRates = extraerRates(results[0]);
    final euroRates = extraerRates(results[1]);

    if (dolarRates.isEmpty || euroRates.isEmpty) return null;

    Map<String, dynamic>? mejorTasaPorFecha(
        List<Map<String, dynamic>> rates) {
      for (final c in rates) {
        final date = DateTime.parse(c['date'] as String);
        final ef = calcularFechaEfectiva(date);
        if (ef.isBefore(limite)) {
          return c;
        }
      }
      return null;
    }

    final mejorUsd = mejorTasaPorFecha(dolarRates);
    final mejorEur = mejorTasaPorFecha(euroRates);
    if (mejorUsd == null || mejorEur == null) return null;

    final usd = (mejorUsd['rate'] as num).toDouble();
    final eur = (mejorEur['rate'] as num).toDouble();
    final fechaTasa = DateTime.parse(mejorUsd['date'] as String);

    return TasaBcv(
      usd: usd,
      eur: eur,
      usdt: 0,
      fecha: fechaTasa,
      origen: 'api',
      fechaEfectiva: calcularFechaEfectiva(fechaTasa),
    );
  }

  Future<TasaBcv?> obtenerTasaHistorica(DateTime fecha) async {
    final fechaLimite = DateTime(fecha.year, fecha.month, fecha.day);

    String formatDate(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}T00:00:00';

    final inicio = formatDate(fecha.subtract(const Duration(days: 7)));
    final fin = formatDate(fecha.add(const Duration(days: 3)));

    final results = await Future.wait([
      http
          .get(Uri.parse(
              '$_baseUrl/history/bcv?currency=dolar&start_date=$inicio&end_date=$fin&limit=10&order=desc'))
          .timeout(const Duration(seconds: 10)),
      http
          .get(Uri.parse(
              '$_baseUrl/history/bcv?currency=euro&start_date=$inicio&end_date=$fin&limit=10&order=desc'))
          .timeout(const Duration(seconds: 10)),
    ]);

    double? usd;
    double? eur;
    DateTime? fechaTasa;

    List<Map<String, dynamic>> extraerRates(http.Response response) {
      if (response.statusCode != 200) return [];
      final body = json.decode(response.body) as Map<String, dynamic>;
      final currencies = body['currencies'] as List<dynamic>? ?? [];
      return currencies.cast<Map<String, dynamic>>();
    }

    final dolarRates = extraerRates(results[0]);
    final euroRates = extraerRates(results[1]);

    if (dolarRates.isEmpty || euroRates.isEmpty) return null;

    Map<String, dynamic>? mejorTasaPorFecha(
        List<Map<String, dynamic>> rates) {
      for (final c in rates) {
        final date = DateTime.parse(c['date'] as String);
        final ef = calcularFechaEfectiva(date);
        if (!ef.isAfter(fechaLimite)) {
          return c;
        }
      }
      return null;
    }

    final mejorUsd = mejorTasaPorFecha(dolarRates);
    final mejorEur = mejorTasaPorFecha(euroRates);
    if (mejorUsd == null || mejorEur == null) return null;

    usd = (mejorUsd['rate'] as num).toDouble();
    eur = (mejorEur['rate'] as num).toDouble();
    fechaTasa = DateTime.parse(mejorUsd['date'] as String);

    return TasaBcv(
      usd: usd,
      eur: eur,
      usdt: 0,
      fecha: fechaTasa,
      origen: 'api',
      fechaEfectiva: calcularFechaEfectiva(fechaTasa),
    );
  }
}
