import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/tasa_bcv.dart';
import '../models/tasa_usdt.dart';

class BcvApiService {
  static const _baseUrl = 'https://dolar-vzla.rafnixg.dev/api/v1';

  Future<TasaBcv> obtenerTasa() async {
    final response = await http.get(Uri.parse('$_baseUrl/bcv/realtime'));

    if (response.statusCode != 200) {
      throw Exception('Error en API: HTTP ${response.statusCode}');
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
      fecha: fecha ?? DateTime.now(),
      origen: 'api',
    );
  }

  Future<TasaUsdt> obtenerTasaUsdt() async {
    final response = await http.get(Uri.parse('$_baseUrl/binance/realtime_ves'));

    if (response.statusCode != 200) {
      throw Exception('Error al obtener USDT: HTTP ${response.statusCode}');
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    final average = (data['average_price'] as num).toDouble();
    final median = (data['median_price'] as num).toDouble();

    return TasaUsdt(
      usdt: median,
      promedio: average,
      fecha: DateTime.now(),
    );
  }

  Future<TasaBcv?> obtenerTasaHistorica(DateTime fecha) async {
    final desde = fecha.subtract(const Duration(days: 7));
    final hasta = fecha.add(const Duration(days: 1));

    String formatDate(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}T00:00:00';

    final results = await Future.wait([
      http.get(Uri.parse(
          '$_baseUrl/history/bcv?currency=dolar&start_date=${formatDate(desde)}&end_date=${formatDate(hasta)}&limit=10')),
      http.get(Uri.parse(
          '$_baseUrl/history/bcv?currency=euro&start_date=${formatDate(desde)}&end_date=${formatDate(hasta)}&limit=10')),
    ]);

    double? usd;
    DateTime? fechaUsd;
    double? eur;
    DateTime? fechaEur;

    for (var i = 0; i < 2; i++) {
      if (results[i].statusCode != 200) continue;
      final body = json.decode(results[i].body) as Map<String, dynamic>;
      final currencies = body['currencies'] as List<dynamic>;

      for (final c in currencies) {
        final map = c as Map<String, dynamic>;
        final rate = (map['rate'] as num).toDouble();
        final date = DateTime.parse(map['date'] as String);

        if (date.isAfter(fecha)) continue;

        if (i == 0 && (fechaUsd == null || date.isAfter(fechaUsd))) {
          usd = rate;
          fechaUsd = date;
        }
        if (i == 1 && (fechaEur == null || date.isAfter(fechaEur))) {
          eur = rate;
          fechaEur = date;
        }
      }
    }

    if (usd == null || eur == null || fechaUsd == null || fechaEur == null) {
      return null;
    }

    final fechaTasa = fechaUsd.isAfter(fechaEur) ? fechaUsd : fechaEur;

    return TasaBcv(
      usd: usd,
      eur: eur,
      fecha: fechaTasa,
      origen: 'api',
    );
  }
}
