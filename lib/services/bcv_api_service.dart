import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/tasa_bcv.dart';

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

    return TasaBcv(
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

  Future<TasaBcv?> obtenerTasaHistorica(DateTime fecha) async {
    String formatDate(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}T00:00:00';

    final inicio = formatDate(fecha);
    final fin = formatDate(fecha.add(const Duration(days: 1)));

    final results = await Future.wait([
      http
          .get(Uri.parse(
              '$_baseUrl/history/bcv?currency=dolar&start_date=$inicio&end_date=$fin&limit=1'))
          .timeout(const Duration(seconds: 10)),
      http
          .get(Uri.parse(
              '$_baseUrl/history/bcv?currency=euro&start_date=$inicio&end_date=$fin&limit=1'))
          .timeout(const Duration(seconds: 10)),
    ]);

    double? usd;
    double? eur;
    DateTime? fechaTasa;

    for (var i = 0; i < 2; i++) {
      if (results[i].statusCode != 200) continue;
      final body = json.decode(results[i].body) as Map<String, dynamic>;
      final currencies = body['currencies'] as List<dynamic>;

      if (currencies.isEmpty) continue;

      final c = currencies.first as Map<String, dynamic>;
      final rate = (c['rate'] as num).toDouble();
      final date = DateTime.parse(c['date'] as String);

      if (i == 0) {
        usd = rate;
        fechaTasa = date;
      } else {
        eur = rate;
      }
    }

    if (usd == null || eur == null || fechaTasa == null) return null;

    return TasaBcv(
      usd: usd,
      eur: eur,
      usdt: 0,
      fecha: fechaTasa,
      origen: 'api',
    );
  }
}
