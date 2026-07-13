import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/tasa_bcv.dart';

class BcvApiService {
  static const _url = 'https://dolar-vzla.rafnixg.dev/api/v1/bcv/realtime';

  Future<TasaBcv> obtenerTasa() async {
    final response = await http.get(Uri.parse(_url));

    if (response.statusCode != 200) {
      throw Exception('Error en API fallback: HTTP ${response.statusCode}');
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
      throw Exception('API fallback no devolvió USD y EUR');
    }

    return TasaBcv(
      usd: usd,
      eur: eur,
      fecha: fecha ?? DateTime.now(),
      origen: 'api',
    );
  }
}
