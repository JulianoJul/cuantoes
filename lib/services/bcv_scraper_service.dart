import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html;
import '../models/tasa_bcv.dart';

class BcvScraperService {
  static const _url = 'https://www.bcv.org.ve/';

  Future<TasaBcv> obtenerTasa() async {
    final response = await http.get(Uri.parse(_url));

    if (response.statusCode != 200) {
      throw Exception('Error al consultar BCV: HTTP ${response.statusCode}');
    }

    final doc = html.parse(response.body);

    final textoUsd = _extraerTexto(doc, '#dolar');
    final textoEur = _extraerTexto(doc, '#euro');

    if (textoUsd == null || textoEur == null) {
      throw Exception('No se encontraron las tasas en la página del BCV');
    }

    final usd = _parsearValor(textoUsd);
    final eur = _parsearValor(textoEur);

    return TasaBcv(
      usd: usd,
      eur: eur,
      fecha: DateTime.now(),
      origen: 'scraping',
    );
  }

  String? _extraerTexto(dynamic doc, String selector) {
    final el = doc.querySelector(selector);
    if (el == null) return null;
    return el.text.trim();
  }

  double _parsearValor(String texto) {
    final match = RegExp(r'[\d,.]+').firstMatch(texto);
    if (match == null) throw Exception('Formato no reconocido: $texto');
    return double.parse(match.group(0)!.replaceAll(',', '.'));
  }
}
