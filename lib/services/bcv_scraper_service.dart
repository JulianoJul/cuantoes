import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import '../models/tasa_bcv.dart';

class BcvScraperService {
  static const _url = 'https://www.bcv.org.ve/';

  Future<TasaBcv?> obtenerTasa() async {
    try {
      final response = await http
          .get(Uri.parse(_url), headers: {
            'User-Agent':
                'Mozilla/5.0 (X11; Linux x86_64; rv:152.0) Gecko/20100101 Firefox/152.0',
            'Accept-Language': 'es-ES,es;q=0.9',
          })
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return null;
      if (response.body.isEmpty) return null;

      return _parsear(response.body);
    } catch (_) {
      return null;
    }
  }

  static const _meses = {
    'enero': 1, 'febrero': 2, 'marzo': 3, 'abril': 4,
    'mayo': 5, 'junio': 6, 'julio': 7, 'agosto': 8,
    'septiembre': 9, 'octubre': 10, 'noviembre': 11, 'diciembre': 12,
  };

  TasaBcv? _parsear(String body) {
    final doc = html_parser.parse(body);

    final usd = _extraerTasa(doc, 'dolar') ?? _extraerTasa(doc, 'usd');
    final eur = _extraerTasa(doc, 'euro') ?? _extraerTasa(doc, 'eur');
    if (usd == null || eur == null) return null;

    final fecha = _extraerFechaValor(body) ?? DateTime.now();

    return TasaBcv(
      usd: usd,
      eur: eur,
      usdt: 0,
      fecha: fecha,
      origen: 'scraping',
    );
  }

  double? _extraerTasa(dynamic doc, String id) {
    try {
      final el = doc.querySelector('#$id') ?? doc.querySelector('.$id');
      if (el == null) return null;
      final raw = el.text.trim().replaceAll('.', '').replaceAll(',', '.');
      return double.tryParse(raw);
    } catch (_) {
      return null;
    }
  }

  DateTime? _extraerFechaValor(String body) {
    try {
      final match = RegExp(
        r'Fecha\s*Valor[:\s]*([^<]+)',
        caseSensitive: false,
      ).firstMatch(body);
      if (match == null) return null;
      return _parsearFecha(match.group(1)!.trim());
    } catch (_) {
      return null;
    }
  }

  DateTime? _parsearFecha(String raw) {
    final sinDia = raw.replaceFirst(RegExp(r'^[^,]+,\s*'), '');
    final parts = sinDia.trim().split(RegExp(r'\s+'));
    if (parts.length != 3) return null;

    final dia = int.tryParse(parts[0]);
    final mes = _meses[parts[1].toLowerCase()];
    final anio = int.tryParse(parts[2]);
    if (dia == null || mes == null || anio == null) return null;

    return DateTime(anio, mes, dia);
  }
}
